from pyomo.environ import *

def define_components(mod):

	"""
    Add the planning reserve factor for capacity
    This is just a translation of the AMPL code.
    It had several errors, but this is just for validating.
    I assume there are no storage projects and that 
    flexible baseload plants are dispatchable.
    """
    
	mod.Capacity_Reserves = Constraint(
        mod.LOAD_ZONES,
        mod.TIMEPOINTS,
        rule = lambda m, lz, t: (
            m.lz_demand_mw[lz, t] * (1 + m.capacity_reserve_margin) * (1 + m.distribution_loss_rate)
            <=
            sum(m.ProjCapacityTP[proj, t] * m.proj_max_capacity_factor[proj, t] 
                for proj in m.VARIABLE_PROJECTS if m.proj_load_zone[proj] == lz) +
            sum(m.ProjCapacityTP[proj, t] * (1 - m.proj_scheduled_outage_rate[proj]) 
                for proj in m.BASELOAD_PROJECTS if m.proj_load_zone[proj] == lz) +
            sum(m.ProjCapacityTP[proj, t] 
                for proj in m.DISPATCHABLE_PROJECTS if m.proj_load_zone[proj] == lz) +
            sum(m.TxPowerReceived[lz_from, lz_to, tp]
                for (lz_from, lz_to, tp) in m.TRANS_TIMEPOINTS
                if lz_to == lz and tp == t) -
            sum(m.TxPowerSent[lz_from, lz_to, tp]
                for (lz_from, lz_to, tp) in m.TRANS_TIMEPOINTS
                if lz_from == lz and tp == t)
            
        ))