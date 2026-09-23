function crj = reconstruction_cij(k,r)
% crj defined by Eq. (2.21) in Shu (1998):
%   V(i+1/2) ≈ ∑_{j=0}^{k-1} crj V(i-r+j),
% where k>0 is oder of accuracy, r non-negative integer left shift.
if k==2
 if r==0
   crj = [1/2;1/2];
 elseif r==1
   crj = [-1/2;3/2];
end  
elseif k==3
 if r==0
   crj = [1/3;5/6;-1/6];
 elseif r==1
   crj = [-1/6;5/6;1/3];
 elseif r==2
   crj = [1/3;-7/6;11/6];
end
elseif k==4
 if r==0
   crj = [1/4;13/12;-5/12;1/12];
 elseif r==1
   crj = [-1/12;7/12;7/12;-1/12];
 elseif r==2
   crj = [1/12;-5/12;13/12;1/4];
 elseif r==3
   crj = [-1/4;13/12;-23/12;25/12];
 end
 elseif k==5
 if r==0
   crj = [1/5;77/60;-43/60;17/60;-1/20];
 elseif r==1
   crj = [-1/20;9/20;47/60;-13/60;1/30];
 elseif r==2
   crj = [1/30;-13/60;47/60;9/20;-1/20];
 elseif r==3
   crj = [-1/20;17/60;-43/60;77/60;1/5];
 elseif r==4
   crj = [1/5;-21/20;137/60;-163/60;137/60];
 end
elseif k==6
 if r==0
   crj = [1/6;29/20;-21/20;37/60;-13/60;1/30];
 elseif r==1
   crj = [-1/30;11/30;19/20;-23/60;7/60;-1/60];
 elseif r==2
   crj = [1/60;-2/15;37/60;37/60;-2/15;1/60];
 elseif r==3
   crj = [-1/60;7/60;-23/60;19/20;11/30;-1/30];
 elseif r==4
   crj = [1/30;-13/60;37/60;-21/20;29/20;1/6];
 elseif r==5
   crj = [-1/6;31/30;-163/60;79/20;-71/20;49/20];
 end
elseif k==7
 if r==0
   crj = [1/7;223/140;-197/140;153/140;-241/420;37/210;-1/42];
 elseif r==1
   crj = [-1/42;13/42;153/140;-241/420;109/420;-31/420;1/105];
 elseif r==2
   crj = [1/105;-19/210;107/210;319/420;-101/420;5/84;-1/140];
 elseif r==3
   crj = [-1/140;5/84;-101/420;319/420;107/210;-19/210;1/105];
 elseif r==4
   crj = [1/105;-31/420;109/420;-241/420;153/140;13/42;-1/42];
 elseif r==5
   crj = [-1/42;37/210;-241/420;153/140;-197/140;223/140;1/7];
 elseif r==6
   crj = [1/7;-43/42;667/210;-2341/420;853/140;-617/140;363/140];
 end
elseif k==1
  crj = 1;
end
%% For general k
%   crj = zeros(k,1);
%   for j=0:k-1
%     for m=j+1:k
%     	deno = 1.0;
%       for l=0:k
%         if l~=m
%           deno = deno * (m-l);
%         end
%       end
%       nume = 0.0;
%       for l=0:k
%         if l~=m
%           temp = 1.0;
%           for q=0:k
%             if q~=m && q~=l
%               temp = temp * (r-q+1);
%             end
%           end
%           nume = nume + temp;
%         end
%       end
%       crj(j+1) = crj(j+1) + nume/deno;
%     end
%   end
end
