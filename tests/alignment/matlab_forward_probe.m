function matlab_forward_probe(root,work)
addpath(fullfile(root,'matlab/util_thermodynamics'));
fid=fopen(fullfile(work,'input.bin'),'r','ieee-le');
input=reshape(fread(fid,1200*5,'double'),[1200,5]); fclose(fid);
T=input(:,1); q=input(:,2); ql=input(:,3); qi=input(:,4); p=input(:,5);
qc=ql+qi; dql=1e-8*ql./qc; dqi=1e-8*qi./qc;
dql(qc<=0)=0; dqi(qc<=0)=0;
base=trace_values(T,q,ql,qi,p);
perturbed=trace_values(T,q,ql+dql,qi+dqi,p);
dqt=-(0.5e-3/20/300)*log(1+exp((20/0.5e-3)*(qc-0.5e-3)));
dtheta=dqt.*(perturbed(:,24)-base(:,24))/1e-8;
dqt(qc<=0)=0; dtheta(qc<=0)=0;
output=[base,perturbed,dtheta,dqt];
assert(isreal(output) && all(isfinite(output),'all'));
fid=fopen(fullfile(work,'matlab.bin'),'w','ieee-le');
fwrite(fid,output,'double'); fclose(fid);
fid=fopen(fullfile(work,'matlab_version.txt'),'w'); fprintf(fid,'%s\n',version); fclose(fid);
end

function result=trace_values(T,q,ql,qi,p)
% Diagnostic intermediates; column 24 calls the unchanged production function.
T0=273.1636783445389; EPS=0.621971830985916;
LV=lv(T); qt=q+ql+qi;
e=p.*q./(q+EPS*(1-qt));
es=eval_es(T).*(T>=T0)+eval_esi(T).*(T<T0);
RE=(1-qt)*287.04; R=RE+q*461.5; CPL=1005.7+qt*3184.3;
chi=RE./CPL; gamma=461.5*q./CPL; gammi=(4190-ci(T0)).*qi./CPL;
a=1e5*R./p./RE; b=es./e; c=T0./T;
x=(q.*LV./T-0.3337e6*qi/T0)./CPL;
fa=a.^chi; fb=b.^gamma; fc=c.^gammi; fx=exp(x);
ya=T.*fa; yb=ya.*fb; yc=yb.*fc; staged=yc.*fx;
native=eval_theta_e(T,q,ql,qi,p);
n=numel(T); constant=@(v) repmat(v,n,1);
result=[constant(EPS),qt,e,es,RE,R,CPL,chi,gamma,gammi,LV,...
        a,b,c,x,fa,fb,fc,fx,ya,yb,yc,staged,native,constant(3184.3),constant(ci(T0))];
end
