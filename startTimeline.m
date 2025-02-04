
function startTimeline(expID,debugOn)
% start a new timeline recording
global timelineSession;

debugOn = 0;

if ~exist('expID','Var')
  expID = newExpID('TEST');
end

if exist('debugOn','Var')
  % then turn on debug plotting of chs
  timelineSession.debug = 0;
  timelineSession.debugFig = rand;
else
  timelineSession.debug = 0;
  timelineSession.debugFig = 0;
end  

animalID = expID(15:end);

disp(['Starting timeline for expID: ',expID]);

% check if DAQ is already running and if so stop/delete it
if ~isempty(timelineSession)
  % disp('Deleting existing DAQ session');
  try
    stopTimeline;
  catch
  end
  try
    timelineSession.daqSession.stop;
    delete(timelineSession.daqSession);
  catch
  end
  try
    delete(timelineSession.daqListen);
  catch
  end
end

% initialisation
timelineSession.daqSession = [];
timelineSession.daqListen = [];
timelineSession.daqData = [];
timelineSession.daqDataPosition = 1;
timelineSession.chNames = [];
timelineSession.expID = expID;
timelineSession.savePath = fullfile(remotePath,animalID,expID,[expID,'_Timeline.mat']);

% create new DAQ session
timelineSession.acqRate = 1000;
timelineSession.daqSession = daq.createSession('ni');
timelineSession.daqSession.Rate = timelineSession.acqRate;
timelineSession.daqSession.IsContinuous = true;

% pull data every 1000 samples
timelineSession.daqSession.NotifyWhenDataAvailableExceeds = 1000;

% add input channels
% timelineSession.chNames{1} = 'EyeCamera';
%addAnalogInputChannel(timelineSession.daqSession,'Dev1', 'ai6', 'Voltage');

% timelineSession.chNames{1} = 'MicroscopeFrames';
% addAnalogInputChannel(timelineSession.daqSession,'Dev1','ai0','Voltage');
% 
% timelineSession.chNames{2} = 'PD';
% addAnalogInputChannel(timelineSession.daqSession,'Dev1', 'ai4', 'Voltage');


timelineSession.chNames{1} = 'MicroscopeFrames';
addAnalogInputChannel(timelineSession.daqSession,'Dev1','ai0','Voltage');
timelineSession.daqSession.Channels(1).Range = [-10 10];
timelineSession.daqSession.Channels(1).TerminalConfig = 'SingleEnded';

timelineSession.chNames{2} = 'Photodiode';
addAnalogInputChannel(timelineSession.daqSession,'Dev1', 'ai4', 'Voltage');
timelineSession.daqSession.Channels(2).Range = [-10 10];
timelineSession.daqSession.Channels(2).TerminalConfig = 'SingleEnded';

timelineSession.chNames{3} = 'EyeCamera';
addAnalogInputChannel(timelineSession.daqSession,'Dev1', 'ai1', 'Voltage');
timelineSession.daqSession.Channels(3).Range = [-10 10];
timelineSession.daqSession.Channels(3).TerminalConfig = 'SingleEnded';

timelineSession.chNames{4} = 'Bonvision';
addAnalogInputChannel(timelineSession.daqSession,'Dev1', 'ai5', 'Voltage');
timelineSession.daqSession.Channels(4).Range = [-10 10];
timelineSession.daqSession.Channels(4).TerminalConfig = 'SingleEnded';

timelineSession.chNames{5} = 'EPhys1';
addAnalogInputChannel(timelineSession.daqSession,'Dev1', 'ai2', 'Voltage'); % +ai6 differential
timelineSession.chNames{6} = 'EPhys2';
addAnalogInputChannel(timelineSession.daqSession,'Dev1', 'ai3', 'Voltage'); % +ai7 differential

% ^ you can change things around here then re run it with startTimeline /
% stopTimeline

% add listener which will be run when new data is available
timelineSession.daqListen = addlistener(timelineSession.daqSession,'DataAvailable', @logData);

% preallocate space for 180 minute recording @ 1000Hz
recordingLength = 180; % minutes

timelineSession.daqData = zeros(round(recordingLength*60*timelineSession.acqRate),length(timelineSession.chNames));

disp('Timeline started');
startBackground(timelineSession.daqSession);
timelineSession.startTime = datetime('now');
end

function logData(src,event)
global timelineSession;
global bvData;
newData = event.Data;
% newData(:,1) = newData(:,1) - (newData(:,2)*-1);
% newData(:,3) = newData(:,3) - (newData(:,4)*-1);
% concatinate new data to stored
timelineSession.daqData(timelineSession.daqDataPosition:timelineSession.daqDataPosition+size(newData,1)-1,:) = newData;
timelineSession.daqDataPosition = timelineSession.daqDataPosition + size(newData,1);
if ~timelineSession.daqSession.IsRunning
  return;
end
% check if we are about to exceed the max data size
if timelineSession.daqDataPosition > size(timelineSession.daqData,1)
  timelineSession.daqSession.stop;
  % this is all a fix to make sure there is nothing in the buffer before
  % killing the daq session
  T = timer('StartDelay',10,'TimerFcn',@(src,evt)stopTimeline);
  start(T)
  % add an hour of space
  %   disp('Increasing timeline capacity...');
  %   samplesToAdd = 60 * 60 * timelineSession.acqRate;
  %   timelineSession.daqData = [timelineSession.daqData;zeros([samplesToAdd,size(timelineSession.daqData,2)])];
  % flush buffer
  msgbox('Timeline has been running more than 3 hours - maybe something crashed and it wasn''t properly stopped or maybe you want to do a really long experiment in which case the cose needs to be altered to accomodate this.');
  return;
else

% debug plotting
if timelineSession.debug
  debugTimeline;
end
%set(groot,'CurrentFigure',timelineSession.tlFig);
%figure(timelineSession.tlFig);
windowSize = 2; % in secs
windowSizeSamples = timelineSession.acqRate * windowSize;
chToAnalyse = 5;

if isfield(bvData,'plotAreas') %only plot if gui open
  %check if plotting figure is still open
  if ~(ishandle(bvData.plotAreas) && strcmp(get(bvData.plotAreas, 'type'), 'figure'))
    bvData.plotAreas = figure('Name','Online analysis','NumberTitle','off','MenuBar', 'None');
    bvData.plotAreas.Position=[app.UIFigure.Position(1)+app.UIFigure.Position(3)+30,app.UIFigure.Position(2),500,app.UIFigure.Position(4)];
  else
    bvData.plotAreas.Position=[bvData.UIFigure.Position(1)+bvData.UIFigure.Position(3),bvData.UIFigure.Position(2),500,bvData.UIFigure.Position(4)];
  end
  
  % check if we have enough data already
  if (timelineSession.daqDataPosition - size(newData,1)) > (windowSizeSamples * 2)
    dataStartSample = timelineSession.daqDataPosition - size(newData,1)-windowSizeSamples;
    dataEndSample = dataStartSample + windowSizeSamples -1;
    dataToProcess = timelineSession.daqData(dataStartSample:dataEndSample,chToAnalyse);
    Fs = timelineSession.acqRate;            % Sampling frequency
    
    
    T = 1/Fs;             % Sampling period
    L = windowSizeSamples;             % Length of signal
    t = (0:L-1)*T;        % Time vector
    
    Y = fft(dataToProcess');
    P2 = abs(Y/L);
    P1 = P2(1:L/2+1);
    P1(2:end-1) = 2*P1(2:end-1);
    f = Fs*(0:(L/2))/L;
    %ax=subplot(2,2,1,'Parent',bvData.plotAreas);
    set(groot,'CurrentFigure',bvData.plotAreas);
    ax=subplot(2,2,1);
    plot(ax,dataToProcess);
    
    %ax = subplot(2,2,2,'Parent',bvData.plotAreas);
    ax = subplot(2,2,2);
    
    plot(ax,f,P1)
    title(ax,'Single-Sided Amplitude Spectrum of X(t)')
    xlabel(ax,'f (Hz)')
    ylabel(ax,'|P1(f)|')
    
    % ax = subplot(2,2,3,'Parent',bvData.plotAreas);
    ax = subplot(2,2,3);
    
    plot(ax,f,P1)
    title(ax,'Single-Sided Amplitude Spectrum of X(t)')
    xlim(ax,[0 20]);
    xlabel(ax,'f (Hz)')
    ylabel(ax,'|P1(f)|')
    
    % ax=subplot(2,2,4,'Parent',bvData.plotAreas);
    ax=subplot(2,2,4);
    
    deltaLow = 0.1; %Hz
    deltaHigh = 3;
    deltaPower = mean(P1(find(f>deltaLow,1):find(f>deltaHigh,1)));
    
    thetaLow = 4; %Hz
    thetaHigh = 12;
    thetaPower = mean(P1(find(f>thetaLow,1):find(f>thetaHigh,1)));
    
    yyaxis(ax,'left');
    bar(ax,[0 1],[deltaPower thetaPower]);
    yyaxis(ax,'right');
    bar(ax,2,thetaPower/deltaPower);
    xticks(ax,[0 1 2]);
    xticklabels(ax,{'delta','theta','ratio'});
    
    drawnow;
  end
  

  
end
end
end
