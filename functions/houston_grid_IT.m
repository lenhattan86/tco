function [cost,capacity,emission] = houston_grid_IT(colocate,nz,ds,off,T,IP,PP,TP,ITR,ITC,CO2_grid,a,au,con,BS,A,S,E,bu,PUE,solar,range1,RC,RE,SR,range2,CRC,CRE,P,GP,RP,BP,plt,location)
a_houston_server = ceil(a./(au'*ones(1,T))/PP);
a_houston_power = a_houston_server*((PP-IP)*au);
if colocate == 1
    a_remaining = a_houston_server*PP*(con-au);
else
    a_remaining = zeros(1,T);
end
b_flat = BS./sum(A,2)*ones(1,T).*A;
cvx_begin
    variables PV GE G(T) b1(size(BS,1),T) b2(size(BS,1),T) D(T) C
    minimize (24*365/T*sum(RC(2)*PV*solar' + CRC(2)*G + GP'.*D)  + RC(1)*PV + CRC(1)*GE + ITC*C)
    subject to
        PV >= range1(1);
        PV <= range1(2);
        C/PP >= max(a_houston_server + sum(b2,1)/bu/PP);
        C >= ITR(1);
        C <= ITR(2);
        sum(b1,1) <= sum(a_remaining,1);
        b1 >= 0;
        b2 >= 0;
        if ds == 0
            b1 + b2 == b_flat;
        end
        if off == 1
            idle_power = (a_houston_server + sum(b2,1)/bu/PP)*IP;
        else
            idle_power = C/PP*IP*ones(1,T);
        end
        sum(A.*b1,2) + sum(A.*b2,2) == BS;
        sum(b1,2) + sum(b2,2) == BS;
        (idle_power+sum(a_houston_power,1) + sum(b1*(PP-IP)/PP,1) + sum(b2,1)*(PP-IP)/PP).*PUE <= D' + PV*solar + G';
        D >= 0;
        D <= TP;
        (idle_power+sum(a_houston_power,1) + sum(b1*(PP-IP)/PP,1) + sum(b2,1)*(PP-IP)/PP).*PUE <= TP;
        G >= 0;
        G <= GE*ones(T,1);
        GE >= range2(1);
        GE <= range2(2);
        if nz == 1
            sum((idle_power+sum(a_houston_power,1) + sum(b1*(PP-IP)/PP,1) + sum(b2,1)*(PP-IP)/PP).*PUE) <= sum(PV*solar + G');
        end
cvx_end

if strcmp(cvx_status, 'Solved') == 0
    cvx_status
end
status = cvx_status;
cvx_optval;
max((idle_power+sum(a_houston_power,1) + sum(b1*(PP-IP)/PP,1) + sum(b2,1)*(PP-IP)/PP).*PUE)
mean((idle_power+sum(a_houston_power,1) + sum(b1*(PP-IP)/PP,1) + sum(b2,1)*(PP-IP)/PP).*PUE)
total_demand = sum((idle_power+sum(a_houston_power,1) + sum(b1*(PP-IP)/PP,1) + sum(b2,1)*(PP-IP)/PP).*PUE);
total_supply = sum(PV*solar + G');
sum(min(PV*solar,(idle_power+sum(a_houston_power,1) + sum(b1*(PP-IP)/PP,1) + sum(b2,1)*(PP-IP)/PP).*PUE))/total_demand
sum(G')/total_demand
sum(D')/total_demand

cost = [PV * RC(1), 24*365/T*sum(RC(2)*PV*solar'), GE * CRC(1), 24*365/T*sum(CRC(2)*G),24*365/T*sum(GP*D), ITC*C];
capacity = [PV, GE, max(D), C];
emission = [24*365/T*sum(RE*PV*solar'), 24*365/T*sum(CRE*G), 24*365/T*CO2_grid*sum(D)];
%{
cost_houston(1) = C * P(1); % IT install cost
cost_houston(2) = C * mean(PUE-1) * P(2); % cooling capaicty cost
cost_houston(3) = C * P(4); % server cost
cost_houston(4) = PV * RC(1); % PV install cost
cost_houston(5) = GE * CRC(1); % GE install cost
cost_houston(6) = 24*365/T*sum(RC(2)*PV*solar'); % PV O&M cost
cost_houston(7) = 24*365/T*sum(CRC(2)*G); % GE O&M cost

capacity_houston(1) = PV;
capacity_houston(2) = GE;
%}

if plt >= 1
    figure;
    bar([PV*solar;G';D']','stacked')
    hold on;
    plot(1:T,(idle_power+sum(a_houston_power,1)+sum(b1/PP*(PP-IP),1)+sum(b2/PP*(PP-IP),1)).*PUE,'r',1:T,TP*ones(1,T),'k', 'LineWidth', 2)
    xlabel('hour');
    ylabel('kW');
    ylim([0,C*1.5]);
    legend('PV generation','Gas Engine generation','Grid power','Power demand','Power capacity')
    xlim([1,T]);
    ylim([0,TP]);
    set (gcf, 'PaperUnits', 'inches', 'PaperPosition', [0.1 0 100.0 20]);
    print ('-depsc', strcat(location,'2.eps'));
    saveas(gcf,strcat(location,'2.fig'))
end

if plt >= 2
    figure;
    pie([sum(min(PV*solar,(idle_power+sum(a_houston_power,1) + sum(b1*(PP-IP)/PP,1) + sum(b2,1)*(PP-IP)/PP).*PUE)), sum(G), sum(D)], {'PV','GE','Grid'})
end

if plt >= 3
    figure;
    bar([a_houston_server;sum(b2,1)/PP/bu]','stacked')
    hold on;
    plot(1:T,C/PP*ones(1,T),'k', 'LineWidth', 2)
    xlabel('hour');
    ylabel('server number');
    xlim([1,T]);
    ylim([0,C/PP*1.1]);
end

if plt >= 4
    figure;
    bar([idle_power;sum(a_houston_power,1);sum(b1/PP*(PP-IP),1)+sum(b2/PP*(PP-IP),1);(idle_power+sum(a_houston_power,1)+sum(b1/PP*(PP-IP),1)+sum(b2/PP*(PP-IP),1)).*(PUE-ones(1,T))]','stacked')
    hold on;
    plot(1:T,C*ones(1,T),'k',1:T,PV*solar+G','r', 'LineWidth', 2)
    xlabel('hour');
    ylabel('kW');
    xlim([1,T]);
    ylim([0,C*1.5]);
    legend('idle power','delay-sensitive workload','delay-tolerant workload','cooling power','IT capacity','renewable')
    %set(gca,'XTick',[0:6:TS], 'FontSize', 8);
    set (gcf, 'PaperUnits', 'inches', 'PaperPosition', [0.1 0 5.0 2.8]);
    print ('-depsc', strcat(location,'.eps'));
    saveas(gcf,strcat(location,'.fig'))
end

if plt >= 5
    figure;
    bar([(idle_power+sum(a_houston_power,1)+sum(b1/PP*(PP-IP),1)+sum(b2/PP*(PP-IP),1)).*PUE]','stacked')
    hold on;
    plot(1:T,TP*ones(1,T),'k',1:T,PV*solar+G','r', 'LineWidth', 2)
    xlabel('hour');
    ylabel('kW');
    xlim([1,T]);
    ylim([0,C*1.5]);
    legend('Power demand','Power capaciity','Local generation')
    %set(gca,'XTick',[0:6:TS], 'FontSize', 8);
    set (gcf, 'PaperUnits', 'inches', 'PaperPosition', [0.1 0 5.0 2.8]);
    print ('-depsc', strcat(location,'2.eps'));
    saveas(gcf,strcat(location,'2.fig'))
end

end

