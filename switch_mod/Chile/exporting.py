# Copyright 2015 The Switch Authors. All rights reserved.
# Licensed under the Apache License, Version 2, which is in the LICENSE file.

"""

This modules writes out output tables with certain processing.
This tables are mostly useful for quick iterations when testing code.

"""
import os
from pyomo.environ import *

def save_results(model, instance, outdir):
    import switch_mod.export as export
    
    summaries_dir = os.path.join(outdir,"Summaries")
    if not os.path.exists(summaries_dir):
        os.makedirs(summaries_dir)

    """
    This table writes out the fuel consumption in MMBTU per hour. 
    """

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
    This table writes out the dispatch of each gen tech on each timepoint and load zone.
    """
    export.write_table(
        instance, instance.TIMEPOINTS, instance.LOAD_ZONES,
        output_file=os.path.join(summaries_dir, "dispatch_proj_by_tech_lz_tp.txt"),
        headings=("load zone", "timepoint",) + tuple(g for g in instance.GENERATION_TECHNOLOGIES),
        values=lambda m, tp, lz: (lz, tp,) + tuple(
            sum(m.DispatchProj[proj, t] for (proj, t) in m.PROJ_DISPATCH_POINTS 
                if m.proj_gen_tech[proj] == g and t == tp and m.proj_load_zone[proj] == lz) 
            for g in m.GENERATION_TECHNOLOGIES)
    )   