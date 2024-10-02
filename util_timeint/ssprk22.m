function X = ssprk22(tspan,X0,dt)
global niter
  y1 = y + dt*expFun(y);
  y1 = elad(y1,y,niter);
  y2 = y1 + dt*expFun(y1);
  y2 = elad(y2,y1,niter);
  y = 0.5*(y + y2);
end
