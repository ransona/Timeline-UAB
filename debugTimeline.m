function debugTimeline()
global timelineSession
try
  set(groot,'CurrentFigure',timelineSession.debugFig);
catch
  timelineSession.debugFig = figure;
end
           
for iCh = 1:length( timelineSession.chNames)
  subplot(length(timelineSession.chNames),1,iCh);
  if timelineSession.daqDataPosition>5000
    plot(timelineSession.daqData( timelineSession.daqDataPosition-5000:timelineSession.daqDataPosition-1000,iCh));
    ylim([-10 10]);
    title([num2str(iCh),' - ',timelineSession.chNames{iCh}]);
  else
    plot(timelineSession.daqData(1:timelineSession.daqDataPosition-1000,iCh));
    ylim([-10 10]);
    title([num2str(iCh),' - ',timelineSession.chNames{iCh}]);
  end
end
  drawnow
end