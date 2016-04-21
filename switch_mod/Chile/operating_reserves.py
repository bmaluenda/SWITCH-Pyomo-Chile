# Copyright 2015 The Switch Authors. All rights reserved.
# Licensed under the Apache License, Version 2, which is in the LICENSE file.

"""
Defines operating reserves components for the SWITCH-Pyomo model.
This module requires that the balancing_areas module also be loaded,
so that the parameters and sets used here are declared and initialized.

SYNOPSIS
>>> from switch_mod.utilities import define_AbstractModel
>>> model = define_AbstractModel(
...     'timescales', 'load_zones', 'balancing_areas', 'reserves.operating_reserves')
>>> instance = model.load_inputs(inputs_dir='test_dat')

"""
import os
from pyomo.environ import *


def define_components(mod):
    """
    LOAD_ZONES_IN_BALANCING_AREA is a set with all the load zones that 
    belong to each balancing area. This set is useful to sum over the 
    reserves provided by units in each lz.

    SpinningReserveProj is a variable that quantifies the amount of
    power a dispatchable generator commits to provide spinning reserves
    in each timepoint.

    SpinningReserveProj is a variable that quantifies the amount of
    power a dispatchable generator commits to provide startup reserves
    in each timepoint.

    DISPATCHABLE_PROJ_DISPATCH_POINTS is a subset of PROJ_DISPATCH_POINTS
    that only includes dispatchable projects. This is used to index the
    reserve requirement constraints.

    Spinning_Reserve_Costs_TP is the expression that adds the cost of 
    fuel burning for standby spinning reserves in a commited unit. This
    doesn't consider the cost of actually using those reserves. That could
    be achieved by considering that a certain fraction of those reserves are
    actually used every year to curb forecast errors or other contingencies
    and so the total fuel cost is reduced, since that commited power is 
    going to be dispatched and it will consume fuel at a higher heat rate.
    """

    mod.LOAD_ZONES_IN_BALANCING_AREA = Set(mod.BALANCING_AREAS, 
        initialize=lambda m, b: set(lz for lz in m.LOAD_ZONES 
            if m.lz_balancing_area[lz] == b ))
    #Created this set just to reduce the number of variables of reserves.
    mod.DISPATCHABLE_PROJ_DISPATCH_POINTS = Set(
        dimen=2,
        initialize=mod.PROJ_DISPATCH_POINTS, 
        filter = lambda m, proj, t: proj in m.DISPATCHABLE_PROJECTS)
    mod.SpinningReserveProj = Var(
        mod.DISPATCHABLE_PROJ_DISPATCH_POINTS,
        within=NonNegativeReals)
    mod.QuickstartReserveProj = Var(
        mod.DISPATCHABLE_PROJ_DISPATCH_POINTS,
        within=NonNegativeReals)
    
    mod.DISPATCHABLE_PROJ_DISP_FUEL_PIECEWISE_CONS_SET = Set(
        dimen=4,
        initialize=mod.PROJ_DISP_FUEL_PIECEWISE_CONS_SET,
        filter=lambda m, proj, t, intercept, incremental_heat_rate: (
            (proj, t) in mod.DISPATCHABLE_PROJ_DISPATCH_POINTS))
    
    mod.ProjSpinningResFuelUseRate = Var(
        mod.PROJ_FUEL_DISPATCH_POINTS,
        within=NonNegativeReals)
    mod.Spinning_Reserve_Costs_TP = Expression(
        mod.TIMEPOINTS,
        rule=lambda m, t: sum(
            m.ProjSpinningResFuelUseRate[proj, t, f] 
                * m.fuel_cost[(m.proj_load_zone[proj], f, m.tp_period[t])]
            for (proj, t2, f) in m.PROJ_FUEL_DISPATCH_POINTS
            if((t2 == t) and (proj in m.DISPATCHABLE_PROJECTS) and (
                (m.proj_load_zone[proj], f, m.tp_period[t]) in
                m.FUEL_AVAILABILITY))))
    mod.cost_components_tp.append('Spinning_Reserve_Costs_TP')

    
    """
    Add balancing area reserves requirements.
    For now, only dispatchable projects provide operating reserves.
    Flexible baseload plants are included in the dispatchable projects.
    It is assumed that the project.unitcommit module is also loaded, 
    since it doesn't make sense to determine spinning reserve
    requirements if units are not being commited. In the same way, if
    no startup costs or ramping constraints exist, then quickstart
    reserves are free and there is no point simulating them.

    Spinning_Reserve_Req is the constraint that forces generators in each
    balancing area to provide enough spinning reserves to fulfill the
    requirements set by the amount of wind and solar capacity available in
    the ba and by the loads. Generation dispatch is constrained by 
    calculating the spinning reserves commited by each proj in each tp 
    as the substraction of the dispatched power from the upper limit of
    its dispatch in that tp. That same difference is used to calculate
    fuel consumption by the provision of those reserves.

    Quickstart_Reserve_Req is the constraint that forces generators in each
    balancing area to provide enough quickstart reserves to fulfill the
    requirements set by the amount of wind and solar capacity available in
    the ba and by the loads. 

    Commit_Spinning_Reserves constraints the spinning reserves provided by
    each unit to be less than or equal to the differece between its commited
    capacity and its actual dispatched power.

    ProjSpinningResFuelUseRate_Calculate computes the fuel consumption due
    to provision of spinning reserves. Only the incremental heat rate costs
    are considered. 

    ---To be implemented---

    Commit_Quickstart_Reserves: I still haven't figured out how to commit
    units to provide quickstart reserves without incurring in costs that
    don't actually exist, because quickstart units are turned off usually.
    One implementation may consider that quickstart reserves are used in a
    certain X percentage, so their costs should be (x/100)*(startupcosts)*
    (generationcosts).

    ProjSpinningResFuelUseRate_Calculate: Startup costs for units that are turned on only for supply of 
    spinning reserves are not considered yet. 
    Also, a similar consideration to what is described in the previous point
    may be implemented. If X percentage of the spinning reserves are actually
    used, then the costs should be modified to consider that (more power would
    be dispatched, but with a lower heat rate).
    """

    mod.Spinning_Reserve_Req = Constraint(mod.BALANCING_AREAS, mod.TIMEPOINTS,
        rule = lambda m, b, t:(
            sum(m.SpinningReserveProj[proj, tp] 
                for (proj, tp) in m.DISPATCHABLE_PROJ_DISPATCH_POINTS if tp == t
                and m.proj_load_zone[proj] in m.LOAD_ZONES_IN_BALANCING_AREA[b])
            >=
            m.spinning_res_load_frac[b] * sum(m.lz_demand_mw[lz, t] 
                for lz in m.LOAD_ZONES_IN_BALANCING_AREA[b]) +
            m.spinning_res_wind_frac[b] * sum(m.ProjCapacityTP[proj, t] * m.proj_max_capacity_factor[proj, t] 
                for (proj, tp) in m.PROJ_DISPATCH_POINTS if m.g_energy_source[m.proj_gen_tech[proj]] == 'Wind' 
                and tp == t and m.proj_load_zone[proj] in m.LOAD_ZONES_IN_BALANCING_AREA[b]) +  
            m.spinning_res_solar_frac[b] * sum(m.ProjCapacityTP[proj, t] * m.proj_max_capacity_factor[proj, t] 
                for (proj, tp) in m.PROJ_DISPATCH_POINTS if m.g_energy_source[m.proj_gen_tech[proj]] == 'Solar' 
                and tp == t and m.proj_load_zone[proj] in m.LOAD_ZONES_IN_BALANCING_AREA[b])
            ))

    mod.Quickstart_Reserve_Req = Constraint(mod.BALANCING_AREAS, mod.TIMEPOINTS,
        rule = lambda m, b, t:(
            sum(m.QuickstartReserveProj[proj, tp] 
                for (proj, tp) in m.DISPATCHABLE_PROJ_DISPATCH_POINTS if tp == t
                and m.proj_load_zone[proj] in m.LOAD_ZONES_IN_BALANCING_AREA[b])
            >=
            m.quickstart_res_load_frac[b] * sum(m.lz_demand_mw[lz, t] 
                for lz in m.LOAD_ZONES_IN_BALANCING_AREA[b]) +
            m.quickstart_res_wind_frac[b] * sum(m.ProjCapacityTP[proj, t] * m.proj_max_capacity_factor[proj, t] 
                for (proj, tp) in m.PROJ_DISPATCH_POINTS if m.g_energy_source[m.proj_gen_tech[proj]] == 'Wind' 
                and tp == t and m.proj_load_zone[proj] in m.LOAD_ZONES_IN_BALANCING_AREA[b]) +
            m.quickstart_res_solar_frac[b] * sum(m.ProjCapacityTP[proj, t] * m.proj_max_capacity_factor[proj, t] 
                for (proj, tp) in m.PROJ_DISPATCH_POINTS if m.g_energy_source[m.proj_gen_tech[proj]] == 'Solar' 
                and tp == t and m.proj_load_zone[proj] in m.LOAD_ZONES_IN_BALANCING_AREA[b])
            ))

    mod.Commit_Spinning_Reserves = Constraint(
        mod.DISPATCHABLE_PROJ_DISPATCH_POINTS,
        rule=lambda m, proj, t: (m.SpinningReserveProj[proj, t] 
            <= m.DispatchUpperLimit[proj, t] - m.DispatchProj[proj, t]          
            )
    )
    
    mod.ProjSpinningResFuelUseRate_Calculate = Constraint(
        mod.DISPATCHABLE_PROJ_DISP_FUEL_PIECEWISE_CONS_SET,
        rule=lambda m, proj, t, intercept, incremental_heat_rate: (
            sum(m.ProjSpinningResFuelUseRate[proj, t, f] 
                for f in m.G_FUELS[m.proj_gen_tech[pr]]) >=
            incremental_heat_rate * m.SpinningReserveProj[proj, t]))
    