function matlab_ice_evidence(work)
% Read completed trajectories; do not integrate or alter thermodynamics.
for label={'single_ice_precip','multi_ice_precip'}
  name=label{1};
  data=load(fullfile(work,['matlab_' name '_history.mat']),'history','times');
  history=data.history;
  assert(isequal(size(history),[801,5,8,31]));
  assert(isequal(data.times,0:4:120));
  loss=squeeze(history(:,5,:,:)); % positive cumulative precipitation qt sink
  assert(all(isfinite(loss),'all'));
  assert(all(loss(:,:,1)==0,'all'));
  increments=diff(loss,1,3);
  assert(all(increments>=0,'all'),'Precipitation accumulation decreased');
  updates=squeeze(any(any(increments>0,1),2));
  assert(all(updates),'A timestep has no active precipitation');
  if startsWith(name,'single'), pulse=1; else, pulse=8; end
  selected=loss(151:170,pulse,end);
  evidence=struct('source','actual MATLAB state slot 5: cumulative precipitation loss',...
    'units','kg/kg','levels',[151,170],'pulse_ace',pulse,...
    'initial_exact_zero',true,'monotonic_everywhere',true,...
    'active_update_count',sum(updates),'total_update_count',30,...
    'final_selected_min',min(selected),'final_selected_max',max(selected),...
    'final_all_aces_max',max(loss(:,:,end),[],'all'));
  fid=fopen(fullfile(work,[name '_ice_evidence.json']),'w');
  fprintf(fid,'%s\n',jsonencode(evidence)); fclose(fid);
  disp(name); disp(evidence);
end
end
