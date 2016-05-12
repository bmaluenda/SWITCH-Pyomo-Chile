# Copyright 2015 The Switch Authors. All rights reserved.
# Licensed under the Apache License, Version 2, which is in the LICENSE file.

"""

This modules writes out output tables with certain processing.
This tables are mostly useful for quick iterations when testing code.

"""
import os, time, sys
from pyomo.environ import *
from switch_mod.financials import *

def define_components(mod):
    #Define dual variables, so that marginal costs can be computed eventually
    if not hasattr(mod, 'dual'):
        mod.dual = Suffix(direction=Suffix.IMPORT)

    #Separate the computation of Investment and Operations cost, for comparison with stochastic problem
    import switch_mod.financials as fin

    def calc_tp_costs_in_period(m, t):
            return sum(
                getattr(m, tp_cost)[t] * m.tp_weight_in_year[t]
                for tp_cost in m.cost_components_tp)

    def calc_annual_costs_in_period(m, p):
            return sum(
                getattr(m, annual_cost)[p]
                for annual_cost in m.cost_components_annual)

    mod.TotalInvestmentCost = Expression(rule=lambda m: sum(calc_annual_costs_in_period(m, p) * fin.uniform_series_to_present_value(
                    m.discount_rate, m.period_length_years[p]) * fin.future_to_present_value(
                    m.discount_rate, (m.period_start[p] - m.base_financial_year)) for p in m.PERIODS))
    mod.TotalOperationsCost = Expression(rule=lambda m: sum(sum(calc_tp_costs_in_period(m, t) for t in m.PERIOD_TPS[p]) * fin.uniform_series_to_present_value(
                    m.discount_rate, m.period_length_years[p]) * fin.future_to_present_value(
                    m.discount_rate, (m.period_start[p] - m.base_financial_year)) for p in m.PERIODS))

def save_results(model, instance, outdir):
    import switch_mod.export as export
    
    summaries_dir = os.path.join(outdir,"Summaries")
    if not os.path.exists(summaries_dir):
        os.makedirs(summaries_dir)


    print "Starting to print summaries"
    sys.stdout.flush()
    start=time.time()

    """
    This table writes out the marginal costs of supplying energy in each timepoint in US$/MWh.
    """
    print "marginal_costs_lz_tp.txt..."
    export.write_table(
        instance, instance.TIMEPOINTS, instance.LOAD_ZONES,
        output_file=os.path.join(summaries_dir, "marginal_costs_lz_tp.txt"),
        headings=("timepoint","load_zones","marginal_cost"),
        values=lambda m, tp, lz: (tp, lz, m.dual[m.Energy_Balance[lz, tp]] / (m.tp_weight_in_year[tp] * uniform_series_to_present_value(
                m.discount_rate, m.period_length_years[m.tp_period[tp]]) * future_to_present_value(
                m.discount_rate, (m.period_start[m.tp_period[tp]] - m.base_financial_year)))
        ))

    """
    This table writes out the fuel consumption in MMBTU per hour. 
    """
    print "fuel_consumption_tp_hourly.txt..."
    export.write_table(
        instance, instance.TIMEPOINTS,
        output_file=os.path.join(summaries_dir, "fuel_consumption_tp_hourly.txt"),
        headings=("timepoint",) + tuple(f for f in instance.FUELS),
        values=lambda m, tp: (tp,) + tuple(
            sum(m.ProjFuelUseRate[proj, t, f] for (proj,t) in m.PROJ_WITH_FUEL_DISPATCH_POINTS 
                if m.g_energy_source[m.proj_gen_tech[proj]] == f and t == tp)
            for f in m.FUELS)
    )
    
    """
    This table writes out the fuel consumption in total MMBTU consumed in each period.
    """
    print "fuel_consumption_periods_total.txt..."
    export.write_table(
        instance, instance.PERIODS,
        output_file=os.path.join(summaries_dir, "fuel_consumption_periods_total.txt"),
        headings=("period",) + tuple(f for f in instance.FUELS),
        values=lambda m, p: (p,) + tuple(
            sum(m.ProjFuelUseRate[proj, tp, f] * m.tp_weight[tp] for (proj, tp) in m.PROJ_WITH_FUEL_DISPATCH_POINTS 
                if tp in m.PERIOD_TPS[p] and m.g_energy_source[m.proj_gen_tech[proj]] == f)
            for f in m.FUELS)
    )

    """
    This table writes out cummulative capacity built for each gen tech on each period.
    """
    print "build_proj_by_tech_p.txt..."
    export.write_table(
        instance, instance.GENERATION_TECHNOLOGIES,
        output_file=os.path.join(summaries_dir, "build_proj_by_tech_p.txt"),
        headings=("gentech","Legacy") + tuple(p for p in instance.PERIODS),
        values=lambda m, g: (g, sum(m.BuildProj[proj, bldyr] for (proj, bldyr) in m.PROJECT_BUILDYEARS
            if m.proj_gen_tech[proj] == g and bldyr not in m.PERIODS)) + tuple(
            sum(m.ProjCapacity[proj, p] for proj in m.PROJECTS if m.proj_gen_tech[proj] == g) 
            for p in m.PERIODS)
    )    

    """
    This table writes out the aggregated dispatch of each gen tech on each timepoint.
    """
    print "dispatch_proj_by_tech_tp.txt..."
    export.write_table(
        instance, instance.TIMEPOINTS,
        output_file=os.path.join(summaries_dir, "dispatch_proj_by_tech_tp.txt"),
        headings=("gentech",) + tuple(g for g in instance.GENERATION_TECHNOLOGIES),
        values=lambda m, tp: (tp,) + tuple(
            sum(m.DispatchProj[proj, t] for (proj, t) in m.PROJ_DISPATCH_POINTS 
                if m.proj_gen_tech[proj] == g and t == tp) 
            for g in m.GENERATION_TECHNOLOGIES)
    )

    """
    Writing Objective Function value.
    """
    print "total_system_costs.txt..."
    with open(os.path.join(summaries_dir, "total_system_costs.txt"),'w+') as f:
        f.write("Total System Costs: "+str(instance.SystemCost())+"\n")
        f.write("Total Investment Costs: "+str(instance.TotalInvestmentCost())+"\n")
        f.write("Total Operations Costs: "+str(instance.TotalOperationsCost()))

    """
    This table writes out the dispatch of each gen tech on each timepoint and load zone.
    #This process is extremely slow, need to make it efficient
    print "dispatch_proj_by_tech_lz_tp.txt..."
    export.write_table(
        instance, instance.TIMEPOINTS, instance.LOAD_ZONES,
        output_file=os.path.join(summaries_dir, "dispatch_proj_by_tech_lz_tp.txt"),
        headings=("load zone", "timepoint",) + tuple(g for g in instance.GENERATION_TECHNOLOGIES),
        values=lambda m, tp, lz: (lz, tp,) + tuple(
            sum(m.DispatchProj[proj, t] for (proj, t) in m.PROJ_DISPATCH_POINTS 
                if m.proj_gen_tech[proj] == g and t == tp and m.proj_load_zone[proj] == lz) 
            for g in m.GENERATION_TECHNOLOGIES)
    )   
    """
    print "Time taken writing summaries: {dur:.2f}s".format(dur=time.time()-start)