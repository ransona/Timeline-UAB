function stopTimeline()
% stop a timeline recording
global timelineSession;
% check if DAQ is already running and if so stop it
if isempty(timelineSession.daqSession)
    warn('Timeline doesn''t seem to be running...')
    return;
else
  disp(['Stopping timeline: ',timelineSession.expID]);
  timelineSession.endTime = datetime('now');
  timelineSession.daqSession.stop;
  timelineSession.acqSecs = seconds(timelineSession.endTime-timelineSession.startTime);
  % check acquisition time approximately matches number of samples
  dataDiff = floor(abs(((timelineSession.daqDataPosition-1)/1000)-timelineSession.acqSecs));
  dataDiff = dataDiff / max([(timelineSession.daqDataPosition/1000/60),timelineSession.acqSecs]);
  disp(['Fraction of missing data = ',num2str(dataDiff*100),'%']);
  % remove unused array space
  timelineSession.daqData = timelineSession.daqData(1:timelineSession.daqDataPosition-1,:);
  % remove DAQ fields
  delete(timelineSession.daqSession);
  delete(timelineSession.daqListen);
  timelineSession = rmfield(timelineSession,'daqSession');
  timelineSession = rmfield(timelineSession,'daqListen');
  timelineSession = rmfield(timelineSession,'daqDataPosition');
  % add time vector
  timelineSession.time = 1/timelineSession.acqRate:1/timelineSession.acqRate:size(timelineSession.daqData,1)/timelineSession.acqRate;
  % save
  disp(['Saving timeline: ',timelineSession.expID]);
  save(timelineSession.savePath,'timelineSession');
end
end