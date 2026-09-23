function theta_e = eval_theta_e_check(T, q, ql, p)
   RD=287.04;
   RV=461.5;
   CPD=1005.7;
   CL=4190;
   EPS=RD/RV;
   P0=1e+05;

    LV = lv(T);
    
    r = q ./ (1.-q-ql);
    rt = (q+ql) ./ (1.-q-ql);
    
    e = p.*q ./ ( EPS+(1.-EPS).*q );
    es = eval_es(T);
    rh = e./es;
    pd = p-e;
    
    chi = RD ./ (CPD + rt*CL);
    gamma = -r.*RV ./ (CPD + rt.*CL);
    

        theta_e = T .* (P0/pd).^chi .* rh.^gamma .* exp(LV.*r ./ (CPD+rt.*CL) ./ T);

        % theta_e = T .* (P0/pd).^chi .* exp(LV.*r ./ (CPD+rt.*CL) ./ T);

    % theta_e(rt>0) = theta_e2(rt>0);