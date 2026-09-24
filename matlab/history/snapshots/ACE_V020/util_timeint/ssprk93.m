function yn = ssprk93(expFun,yn,dTH,dQt,rho0B,dt,Wbar_eq_zero,Ai,ace)
  % y(z,var,ACE-i)=[theta_e,qt,MF,dtheta_e_pr_accum,pr_accum]
  K1 = expFun(yn,dTH,dQt,rho0B,ace); %expFun(y,rkstage)
  yi = yn+(dt/6)*K1;
%       yi(:,2,:) = yi(:,2,:).*( yi(:,2,:)>0 ); % Non-negative qt
  K2 = expFun(yi,dTH,dQt,rho0B,ace);
  yi = yn+(dt/6)*(K1+K2);
%       yi(:,2,:) = yi(:,2,:).*( yi(:,2,:)>0 ); 
  K2 = K2 + expFun(yi,dTH,dQt,rho0B,ace);
  yi = yn+(dt/6)*(K1+K2);
%       yi(:,2,:) = yi(:,2,:).*( yi(:,2,:)>0 ); 
  K2 = K2 + expFun(yi,dTH,dQt,rho0B,ace);
  yi = yn+(dt/6)*(K1+K2);
%       yi(:,2,:) = yi(:,2,:).*( yi(:,2,:)>0 ); 
  K2 = K2 + expFun(yi,dTH,dQt,rho0B,ace);
  yi = yn+(dt/6)*(K1+K2);
%       yi(:,2,:) = yi(:,2,:).*( yi(:,2,:)>0 ); 
  K2 = (K2 + expFun(yi,dTH,dQt,rho0B,ace))/15;
  yi = yn+dt*(K1/6+K2);
%       yi(:,2,:) = yi(:,2,:).*( yi(:,2,:)>0 ); 
  K1 = K1 + expFun(yi,dTH,dQt,rho0B,ace);
  yi = yn+dt*(K1/6+K2);
%       yi(:,2,:) = yi(:,2,:).*( yi(:,2,:)>0 );
  K1 = K1 + expFun(yi,dTH,dQt,rho0B,ace);
  yi = yn+dt*(K1/6+K2);
%       yi(:,2,:) = yi(:,2,:).*( yi(:,2,:)>0 );
  yn = yn + dt*((K1 + expFun(yi,dTH,dQt,rho0B,ace))/6+K2);
  yn(:,2,:) = yn(:,2,:).*( yn(:,2,:)>0 ); % Non-negative qt
  if Wbar_eq_zero==1
    % Adjust mass flux tendency for outermost ACE for neutual domain mean
    yn(:,3,:) = yn(:,3,:) - sum(yn(:,3,:).*permute(Ai/sum(Ai),[3,2,1]),3);
  end 
end