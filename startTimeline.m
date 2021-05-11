
function startTimeline(expID)
% start a new timeline recording
global timelineSession;

if ~exist('expID','Var')
    expID = newExpID('TEST');
end

animalID = expID(15:end);

disp(['Starting timeline for expID: ',expID]);

timelineSession.tlFig = figure;

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
timelineSession.chNames{1} = 'MicroscopeFrames';
addAnalogInputChannel(timelineSession.daqSession,'Dev1','ai0','Voltage');

timelineSession.chNames{2} = 'BonVision';
addAnalogInputChannel(timelineSession.daqSession,'Dev1', 'ai1', 'Voltage');

timelineSession.chNames{3} = 'EyeCamera';
addAnalogInputChannel(timelineSession.daqSession,'Dev1', 'ai2', 'Voltage');

timelineSession.chNames{4} = 'BehaviourCamera';
addAnalogInputChannel(timelineSession.daqSession,'Dev1', 'ai3', 'Voltage');

timelineSession.chNames{5} = 'Lick';
addAnalogInputChannel(timelineSession.daqSession,'Dev1', 'ai4', 'Voltage');

timelineSession.chNames{6} = 'Reward';
addAnalogInputChannel(timelineSession.daqSession,'Dev1', 'ai5', 'Voltage');

timelineSession.chNames{7} = 'EPhys1';
addAnalogInputChannel(timelineSession.daqSession,'Dev1', 'ai6', 'Voltage');

timelineSession.chNames{8} = 'EPhys2';
addAnalogInputChannel(timelineSession.daqSession,'Dev1', 'ai7', 'Voltage');

% add listener which will be run when new data is available
timelineSession.daqListen = addlistener(timelineSession.daqSession,'DataAvailable', @logData);

% preallocate space for 120 minute recording @ 1000Hz
recordingLength = 120; % minutes

timelineSession.daqData = zeros(round(recordingLength*60*timelineSession.acqRate),length(timelineSession.chNames));

disp('Timeline started');
startBackground(timelineSession.daqSession);
timelineSession.startTime = datetime('now');
end

function logData(src,event)
global timelineSession;

newData = event.Data;
% concatinate new data to stored
timelineSession.daqData(timelineSession.daqDataPosition:timelineSession.daqDataPosition+size(newData,1)-1,:) = newData;
timelineSession.daqDataPosition = timelineSession.daqDataPosition + size(newData,1);
% check if we are about to exceed the max data size
if timelineSession.daqDataPosition > size(timelineSession.daqData,1)
    % add an hour of space
    disp('Increasing timeline capacity...');
    samplesToAdd = 60 * 60 * timelineSession.acqRate;
    timelineSession.daqData = [timelineSession.daqData;zeros([samplesToAdd,size(timelineSession.daqData,2)])];
end
%size(newData,1)
set(groot,'CurrentFigure',timelineSession.tlFig);
%figure(timelineSession.tlFig);
windowSize = 2; % in secs
windowSizeSamples = timelineSession.acqRate * windowSize;
chToAnalyse = 7;
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
    subplot(2,2,1);
    plot(t,dataToProcess);
    
    subplot(2,2,2);
    plot(f,P1)
    title('Single-Sided Amplitude Spectrum of X(t)')
    xlabel('f (Hz)')
    ylabel('|P1(f)|')
    
    subplot(2,2,3);
    plot(f,P1)
    title('Single-Sided Amplitude Spectrum of X(t)')
    xlim([0 20]);
    xlabel('f (Hz)')
    ylabel('|P1(f)|')
    
    subplot(2,2,4);
    deltaLow = 0.1; %Hz
    deltaHigh = 3;
    deltaPower = mean(P1(find(f>deltaLow,1):find(f>deltaHigh,1)));
    
    thetaLow = 4; %Hz
    thetaHigh = 12;
    thetaPower = mean(P1(find(f>thetaLow,1):find(f>thetaHigh,1)));
    
    yyaxis('left');
    bar([0 1],[deltaPower thetaPower]);
    yyaxis('right');
    bar(2,thetaPower/deltaPower);
    xticks([0 1 2]);
    xticklabels({'delta','theta','ratio'});
end
end
