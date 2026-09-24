function B = eval_B(Tv,Tv_ref)
  B = 9.80665*(Tv-Tv_ref)./Tv_ref;
end