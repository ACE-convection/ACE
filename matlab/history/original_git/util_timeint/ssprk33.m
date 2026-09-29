??? function X = ssprk33(tspan,X0,dt)
global niter
  y1 = yn + dt*expFun(t,yn);
  y2 = 0.75*yn + 0.25*(y1 + dt*expFun(t,y1));
  yn = (yn + 2*(y2 + dt*expFun(t,y2)))/3;
end
