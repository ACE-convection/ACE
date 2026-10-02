function sweep_inversion(configuration)
% Execute instrumented copies of the actual scalar inverse routines.
% Production physics is untouched by test-only counters/iteration caps.
cfg=jsondecode(fileread(configuration));
addpath(cfg.work);
addpath(fullfile(cfg.root,'matlab/util_thermodynamics'));
started=tic;
if strcmp(cfg.mode,'focused')
  [focused,labels]=focused_inputs();
  jobs=0;
elseif strcmp(cfg.mode,'pilot')
  jobs=unique([cfg.first_pressure_index,0,1,2,200,500,1000,1500,1900,2000,2099,2100,cfg.stop_pressure_index-1]);
  jobs=jobs(jobs>=cfg.first_pressure_index & jobs<cfg.stop_pressure_index);
else
  jobs=cfg.first_pressure_index:cfg.stop_pressure_index-1;
end
summary=empty_summary();
summary.mode=cfg.mode; summary.completed=false;
summary.configuration=cfg;
summary.matlab_version=version;
if strcmp(cfg.mode,'focused')
  summary.requested_cases=size(focused,1);
elseif strcmp(cfg.mode,'pilot')
  summary.requested_cases=numel(jobs)*13*14;
else
  summary.requested_cases=numel(jobs)*401*1001;
end
job_index=1; offset=0;
checkpoint=fullfile(cfg.work,'checkpoint.mat');
if isfile(checkpoint)
  saved=load(checkpoint,'summary','job_index','offset');
  summary=saved.summary; job_index=saved.job_index; offset=saved.offset;
end
while job_index<=numel(jobs)
  if strcmp(cfg.mode,'focused')
    total=size(focused,1);
  elseif strcmp(cfg.mode,'pilot')
    total=13*14;
  else
    total=401*1001;
  end
  while offset<total
    if isfile(fullfile(cfg.work,'STOP'))
      summary.completed=false;
      write_json(fullfile(cfg.work,'summary.json'),summary);
      fprintf('Stopped at checkpoint: %d / %d cases.\n',summary.processed,summary.requested_cases);
      return;
    end
    count=min(cfg.chunk_size,total-offset);
    indices=(offset:offset+count-1)';
    if strcmp(cfg.mode,'focused')
      inputs=focused(indices+1,:);
    elseif strcmp(cfg.mode,'pilot')
      tidx=[0,1,2,50,100,150,200,250,300,350,398,399,400];
      qidx=[0,1,2,5,10,20,50,100,200,400,600,800,999,1000];
      inputs=[200+0.5*tidx(floor(indices/14)+1)',qidx(mod(indices,14)+1)'/10000, ...
              repmat((1100-0.5*jobs(job_index))*100,count,1)];
    else
      inputs=[200+0.5*floor(indices/1001),mod(indices,1001)/10000, ...
              repmat((1100-0.5*jobs(job_index))*100,count,1)];
    end
    input_file=fullfile(cfg.work,'current_input.bin');
    fortran_file=fullfile(cfg.work,'current_fortran.bin');
    keep=true(count,1); diagnosis=NaN(count,2);
    if cfg.exclude_es_above_p
      for row=1:count
        [diagnostic_T,diagnostic_es]=diagnostic_reference(inputs(row,1),inputs(row,2),inputs(row,3));
        diagnosis(row,:)=[diagnostic_T,diagnostic_es];
        keep(row)=~(isreal(diagnostic_es) && isfinite(diagnostic_es) && diagnostic_es>inputs(row,3));
      end
    end
    retained=find(keep);
    m=NaN(count,13); f=m;
    m(:,5:8)=0; m(:,9)=-1; m(:,10:11)=0; m(:,12)=4; m(:,13)=0;
    f=m;
    if ~isempty(retained)
    fid=fopen(input_file,'w','ieee-le');
    assert(fid>=0,'Cannot write shared inputs');
    fwrite(fid,int32(numel(retained)),'int32'); fwrite(fid,inputs(retained,:),'double'); fclose(fid);
    command=sprintf('%s %s %s',shell_quote(fullfile(cfg.work,'inversion_probe')), ...
      shell_quote(input_file),shell_quote(fortran_file));
    [exitcode,output]=system(command);
    assert(exitcode==0,'Fortran probe failed: %s',output);
    fid=fopen(fortran_file,'r','ieee-le');
    output=fread(fid,[numel(retained),13],'double'); fclose(fid);
    assert(isequal(size(output),[numel(retained),13]),'Incomplete Fortran output');
    f(retained,:)=output;
    end
    for row=retained'
      [T,q,ql,qi,branch,n1,n2,status,initial_failure]=reference_inversion(inputs(row,1),inputs(row,2),inputs(row,3));
      values=[T,q,ql,qi];
      m(row,:)=[real(values),imag(values),branch,n1,n2,status,initial_failure];
    end
    if strcmp(cfg.mode,'focused')
      chunk_labels=labels(indices+1);
      save(fullfile(cfg.work,sprintf('focused_%07d.mat',offset)),'inputs','m','f','chunk_labels','diagnosis');
      write_json(fullfile(cfg.work,sprintf('focused_%07d.json',offset)), ...
        struct('labels',{labels(indices+1)},'inputs',inputs,'matlab',m,'fortran',f));
    end
    summary=accumulate(summary,inputs,m,f);
    excluded=find(~keep);
    for row=excluded(1:min(numel(excluded),max(0,12-numel(summary.exclusion_examples))))'
      summary.exclusion_examples{end+1}=struct('input_theta_e_qt_p',inputs(row,:), ...
        'reference_no_condensate_T_es',diagnosis(row,:));
    end
    offset=offset+count;
    summary.elapsed_seconds=summary.elapsed_seconds+toc(started); started=tic;
    save(checkpoint,'summary','job_index','offset');
    write_json(fullfile(cfg.work,'summary.json'),summary);
    fprintf('%s: %d / %d, finite converged pairs %d, capped MATLAB/Fortran %d/%d, elapsed %.1f s\n', ...
      cfg.mode,summary.processed,summary.requested_cases,summary.comparable, ...
      summary.matlab_status_counts(2),summary.fortran_status_counts(2),summary.elapsed_seconds);
  end
  job_index=job_index+1; offset=0;
end
summary.completed=true;
summary.full_cartesian_grid_complete=strcmp(cfg.mode,'full') && summary.requested_cases==cfg.full_grid_count;
save(checkpoint,'summary','job_index','offset');
write_json(fullfile(cfg.work,'summary.json'),summary);
end

function quoted=shell_quote(value)
apostrophe=char(39);
quoted=[apostrophe,strrep(value,apostrophe,[apostrophe,char(34),apostrophe,char(34),apostrophe]),apostrophe];
end

function s=empty_summary()
s.processed=0; s.comparable=0; s.exact_value_pairs=0; s.bitwise_equal_pairs=0;
s.full_cartesian_grid_complete=false;
s.status_mismatches=0; s.branch_mismatches=0; s.iteration_mismatches=0;
s.initial_failure_mismatches=0;
s.excluded_cases=0; s.exclusion_examples={};
s.matlab_status_counts=zeros(1,5); s.fortran_status_counts=zeros(1,5);
s.matlab_branch_counts=zeros(1,4); s.fortran_branch_counts=zeros(1,4);
s.max_abs=zeros(1,4); s.max_rel_nonzero_reference=zeros(1,4);
s.zero_reference_nonzero_difference=zeros(1,4);
s.worst_abs=cell(1,4); s.worst_rel=cell(1,4);
s.matlab_invalid_partition=0; s.fortran_invalid_partition=0;
s.exception_examples={}; s.difference_examples={}; s.elapsed_seconds=0;
s.variable_order={'T','qv','ql','qi'};
s.relative_error_definition='abs(Fortran-MATLAB)/abs(MATLAB) for nonzero MATLAB reference; zero references counted separately';
s.acceptance='No numerical acceptance tolerance; exact-value and bitwise equality reported separately';
end

function s=accumulate(s,inputs,m,f)
s.processed=s.processed+size(inputs,1);
for code=0:4
  s.matlab_status_counts(code+1)=s.matlab_status_counts(code+1)+sum(m(:,12)==code);
  s.fortran_status_counts(code+1)=s.fortran_status_counts(code+1)+sum(f(:,12)==code);
end
s.excluded_cases=s.excluded_cases+sum(m(:,12)==4 & f(:,12)==4);
for code=0:3
  s.matlab_branch_counts(code+1)=s.matlab_branch_counts(code+1)+sum(m(:,9)==code);
  s.fortran_branch_counts(code+1)=s.fortran_branch_counts(code+1)+sum(f(:,9)==code);
end
s.status_mismatches=s.status_mismatches+sum(m(:,12)~=f(:,12));
s.branch_mismatches=s.branch_mismatches+sum(m(:,9)~=f(:,9));
s.iteration_mismatches=s.iteration_mismatches+sum(any(m(:,10:11)~=f(:,10:11),2));
s.initial_failure_mismatches=s.initial_failure_mismatches+sum(m(:,13)~=f(:,13));
valid=m(:,12)==0 & f(:,12)==0;
s.comparable=s.comparable+sum(valid);
s.matlab_invalid_partition=s.matlab_invalid_partition+sum(m(:,12)==0 & any(m(:,2:4)<0,2));
s.fortran_invalid_partition=s.fortran_invalid_partition+sum(f(:,12)==0 & any(f(:,2:4)<0,2));
s.exact_value_pairs=s.exact_value_pairs+sum(valid & all(m(:,1:4)==f(:,1:4),2));
mbits=reshape(typecast(reshape(m(:,1:4),[],1),'uint64'),size(m,1),4);
fbits=reshape(typecast(reshape(f(:,1:4),[],1),'uint64'),size(f,1),4);
s.bitwise_equal_pairs=s.bitwise_equal_pairs+sum(valid & all(mbits==fbits,2));
rows=find(valid);
for variable=1:4
  delta=abs(m(rows,variable)-f(rows,variable));
  [error,index]=max(delta);
  if ~isempty(error) && (isempty(s.worst_abs{variable}) || error>s.max_abs(variable))
    s.max_abs(variable)=error;
    s.worst_abs{variable}=example(inputs,m,f,rows(index));
  end
  nonzero=m(rows,variable)~=0;
  relrows=rows(nonzero);
  relative=delta(nonzero)./abs(m(relrows,variable));
  [error,index]=max(relative);
  if ~isempty(error) && (isempty(s.worst_rel{variable}) || error>s.max_rel_nonzero_reference(variable))
    s.max_rel_nonzero_reference(variable)=error;
    s.worst_rel{variable}=example(inputs,m,f,relrows(index));
  end
  s.zero_reference_nonzero_difference(variable)=s.zero_reference_nonzero_difference(variable)+sum(~nonzero & delta~=0);
end
exceptions=find((~valid & m(:,12)~=4) | m(:,12)~=f(:,12) | m(:,9)~=f(:,9) | any(m(:,10:11)~=f(:,10:11),2));
for row=exceptions(1:min(numel(exceptions),max(0,12-numel(s.exception_examples))))'
  s.exception_examples{end+1}=example(inputs,m,f,row);
end
differences=find(valid & any(m(:,1:4)~=f(:,1:4),2));
for row=differences(1:min(numel(differences),max(0,12-numel(s.difference_examples))))'
  s.difference_examples{end+1}=example(inputs,m,f,row);
end
end

function e=example(inputs,m,f,row)
e=struct('input_theta_e_qt_p',inputs(row,:),'matlab',m(row,:),'fortran',f(row,:));
end

function write_json(file,value)
fid=fopen([file '.tmp'],'w'); assert(fid>=0);
fprintf(fid,'%s\n',jsonencode(value)); fclose(fid);
movefile([file '.tmp'],file,'f');
end

function [inputs,labels]=focused_inputs()
inputs=[]; labels={};
T0=273.1636783445389;
pressures=[110000,100000,90000,70000,50000,30000,10000,5000];
for pressure=pressures
  for temperature=[200,220,250,273.15,273.16,T0,273.17,280,300,320]
    if temperature>=T0, saturation=eval_qs(temperature,pressure);
    else, saturation=eval_qsi(temperature,pressure); end
    % Keep manufactured states within the requested qt range and away from e>=p.
    if saturation<=0 || saturation>=0.1, continue; end
    for fraction=[0.01,0.5,0.999999,1,1.000001]
      vapor=saturation*fraction;
      if vapor>0.1, continue; end
      theta=eval_theta_e(temperature,vapor,0,0,pressure);
      inputs(end+1,:)=[theta,vapor,pressure];
      labels{end+1}=sprintf('no_condensate_T%.9g_p%.9g_RH%.9g',temperature,pressure,fraction);
    end
    for condensate=[1e-9,0.00001,0.0005,0.002]
      vapor=saturation*(1-condensate);
      if vapor+condensate>0.1, continue; end
      liquid=condensate*(temperature>=T0); ice=condensate*(temperature<T0);
      theta=eval_theta_e(temperature,vapor,liquid,ice,pressure);
      inputs(end+1,:)=[theta,vapor+condensate,pressure];
      labels{end+1}=sprintf('condensate_T%.9g_p%.9g_qc%.9g',temperature,pressure,condensate);
    end
    if temperature==T0
      liquid=0.0006; ice=0.0004; vapor=saturation*(1-liquid-ice);
      theta=eval_theta_e(temperature,vapor,liquid,ice,pressure);
      inputs(end+1,:)=[theta,vapor+liquid+ice,pressure];
      labels{end+1}=sprintf('mixed_phase_p%.9g',pressure);
    end
  end
  for theta=[200,273.16,300,400]
    inputs(end+1,:)=[theta,0,pressure];
    labels{end+1}=sprintf('dry_theta%.9g_p%.9g',theta,pressure);
  end
end
end
