
# Reopen the OpenStudio class to add methods to apply standards to this object
class OpenStudio::Model::AirLoopHVAC

  # Apply all standard required controls to the airloop
  #
  # @param (see #isEconomizerRequired)
  # @return [Bool] returns true if successful, false if not
  # @todo optimum start
  # @todo night damper shutoff
  # @todo nightcycle control
  # @todo night fan shutoff
  def applyStandardControls(template, climate_zone)
    
    # Adjust multizone VAV damper positions
    if self.is_multizone_vav_system
      self.set_minimum_vav_damper_positions
    end

    # Economizers
    self.setEconomizerLimits(template, climate_zone)
    self.setEconomizerIntegration(template, climate_zone)    
    
    # Multizone VAV Optimization
    if self.is_multizone_vav_system
      if self.is_multizone_vav_optimization_required(template, climate_zone)
        self.enable_multizone_vav_optimization
      else
        self.disable_multizone_vav_optimization
      end
    end
    
    # DCV
    if self.is_demand_control_ventilation_required(template, climate_zone)
      self.enable_demand_control_ventilation
    else
      # Need to convert the design spec OA objects
      # to per-area only so that if VRP is 
    
    end
    
    # Modify ventilation rates if multizone optimization
    # is required but DCV is not.
    
    # TODO Optimum Start
    # for systems exceeding 10,000 cfm
    
    # TODO night damper shutoff
    
    # TODO night cycle
    
    # TODO night fan shutoff > 0.75 hp
 
  end  

  # Determine the fan power limitation pressure drop adjustment
  # Per Table 6.5.3.1.1B
  #
  # @param template [String] valid choices: 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
  # @return [Double] fan power limitation pressure drop adjustment
  #   units = horsepower
  # @todo Determine the presence of MERV filters and other stuff in Table 6.5.3.1.1B.  May need to extend AirLoopHVAC data model
  def fanPowerLimitationPressureDropAdjustmentBrakeHorsepower(template = "ASHRAE 90.1-2007")
  
   # Get design supply air flow rate (whether autosized or hard-sized)
    dsn_air_flow_m3_per_s = 0
    dsn_air_flow_cfm = 0
    if self.autosizedDesignSupplyAirFlowRate.is_initialized
      dsn_air_flow_m3_per_s = self.autosizedDesignSupplyAirFlowRate.get
      dsn_air_flow_cfm = OpenStudio.convert(dsn_air_flow_m3_per_s, "m^3/s", "cfm").get
      OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "* #{dsn_air_flow_cfm.round} cfm = Autosized Design Supply Air Flow Rate.")
    else
      dsn_air_flow_m3_per_s = self.designSupplyAirFlowRate.get
      dsn_air_flow_cfm = OpenStudio.convert(dsn_air_flow_m3_per_s, "m^3/s", "cfm").get
      OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "* #{dsn_air_flow_cfm.round} cfm = Hard sized Design Supply Air Flow Rate.")
    end  
  
    # TODO determine the presence of MERV filters and other stuff
    # in Table 6.5.3.1.1B
    # perhaps need to extend AirLoopHVAC data model
    has_fully_ducted_return_and_or_exhaust_air_systems = false
    
    # Calculate Fan Power Limitation Pressure Drop Adjustment (in wc)
    fan_pwr_adjustment_in_wc = 0
    
    # Fully ducted return and/or exhaust air systems
    if has_fully_ducted_return_and_or_exhaust_air_systems
      adj_in_wc = 0.5
      fan_pwr_adjustment_in_wc += adj_in_wc
      OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC","--Added #{adj_in_wc} in wc for Fully ducted return and/or exhaust air systems")
    end
    
    # Convert the pressure drop adjustment to brake horsepower (bhp)
    # assuming that all supply air passes through all devices
    fan_pwr_adjustment_bhp = fan_pwr_adjustment_in_wc * dsn_air_flow_cfm / 4131
    OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC","#{self.name} - #{(fan_pwr_adjustment_bhp)} bhp = Fan Power Limitation Pressure Drop Adjustment")
 
    return fan_pwr_adjustment_bhp
 
  end

  # Determine the allowable fan system brake horsepower
  # Per Table 6.5.3.1.1A
  #
  # @param template [String] valid choices: 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
  # @return [Double] allowable fan system brake horsepower
  #   units = horsepower
  def allowableSystemBrakeHorsepower(template = "ASHRAE 90.1-2007")
  
   # Get design supply air flow rate (whether autosized or hard-sized)
    dsn_air_flow_m3_per_s = 0
    dsn_air_flow_cfm = 0
    if self.autosizedDesignSupplyAirFlowRate.is_initialized
      dsn_air_flow_m3_per_s = self.autosizedDesignSupplyAirFlowRate.get
      dsn_air_flow_cfm = OpenStudio.convert(dsn_air_flow_m3_per_s, "m^3/s", "cfm").get
      OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "* #{dsn_air_flow_cfm.round} cfm = Autosized Design Supply Air Flow Rate.")
    else
      dsn_air_flow_m3_per_s = self.designSupplyAirFlowRate.get
      dsn_air_flow_cfm = OpenStudio.convert(dsn_air_flow_m3_per_s, "m^3/s", "cfm").get
      OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "* #{dsn_air_flow_cfm.round} cfm = Hard sized Design Supply Air Flow Rate.")
    end

    # Get the fan limitation pressure drop adjustment bhp
    fan_pwr_adjustment_bhp = self.fanPowerLimitationPressureDropAdjustmentBrakeHorsepower
    
    # Determine the number of zones the system serves
    num_zones_served = self.thermalZones.size
    
    # Get the supply air fan and determine whether VAV or CAV system.
    # Assume that supply air fan is fan closest to the demand outlet node.
    # The fan may be inside of a piece of unitary equipment.
    fan_pwr_limit_type = nil
    self.supplyComponents.reverse.each do |comp|
      if comp.to_FanConstantVolume.is_initialized || comp.to_FanOnOff.is_initialized
        fan_pwr_limit_type = "constant volume"
      elsif comp.to_FanConstantVolume.is_initialized
        fan_pwr_limit_type = "variable volume"
      elsif comp.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.is_initialized
        fan = comp.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.get.supplyAirFan
        if fan.to_FanConstantVolume.is_initialized || comp.to_FanOnOff.is_initialized
          fan_pwr_limit_type = "constant volume"
        elsif fan.to_FanConstantVolume.is_initialized
          fan_pwr_limit_type = "variable volume"
        end
      elsif comp.to_AirLoopHVACUnitarySystem.is_initialized
        fan = comp.to_AirLoopHVACUnitarySystem.get.supplyFan
        if fan.to_FanConstantVolume.is_initialized || comp.to_FanOnOff.is_initialized
          fan_pwr_limit_type = "constant volume"
        elsif fan.to_FanConstantVolume.is_initialized
          fan_pwr_limit_type = "variable volume"
        end
      end  
    end
    
    # For 90.1-2010, single-zone VAV systems use the 
    # constant volume limitation per 6.5.3.1.1
    if template == "ASHRAE 90.1-2010" && fan_pwr_limit_type = "variable volume" && num_zones_served == 1
      fan_pwr_limit_type = "constant volume"
      OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC","#{self.name} - Using the constant volume limitation because single-zone VAV system.")
    end
    
    # Calculate the Allowable Fan System brake horsepower per Table G3.1.2.9
    allowable_fan_bhp = 0
    if fan_pwr_limit_type == "constant volume"
      allowable_fan_bhp = dsn_air_flow_cfm * 0.0013 + fan_pwr_adjustment_bhp
    elsif fan_pwr_limit_type == "variable volume"
      allowable_fan_bhp = dsn_air_flow_cfm * 0.00094 + fan_pwr_adjustment_bhp
    end
    OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC","#{self.name} - #{(allowable_fan_bhp).round(2)} bhp = Allowable brake horsepower.")
    
    return allowable_fan_bhp

  end

  # Get all of the supply, return, exhaust, and relief fans on this system
  #
  # @return [Array] an array of FanConstantVolume, FanVariableVolume, and FanOnOff objects
  def supplyReturnExhaustReliefFans() 
    
    # Fans on the supply side of the airloop directly, or inside of unitary equipment.
    fans = []
    sup_and_oa_comps = self.supplyComponents
    sup_and_oa_comps += self.oaComponents
    sup_and_oa_comps.each do |comp|
      if comp.to_FanConstantVolume.is_initialized || comp.to_FanVariableVolume.is_initialized
        fans << comp
      elsif comp.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.is_initialized
        sup_fan = comp.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.get.supplyAirFan
        if sup_fan.to_FanConstantVolume.is_initialized
          fans << sup_fan.to_FanConstantVolume.get
        elsif sup_fan.to_FanOnOff.is_initialized
          fans << sup_fan.to_FanOnOff.get
        end
      elsif comp.to_AirLoopHVACUnitarySystem.is_initialized
        sup_fan = comp.to_AirLoopHVACUnitarySystem.get.supplyFan
        if sup_fan.to_FanConstantVolume.is_initialized
          fans << sup_fan.to_FanConstantVolume.get
        elsif sup_fan.to_FanOnOff.is_initialized
          fans << sup_fan.to_FanOnOff.get
        elsif sup_fan.to_FanVariableVolume.is_initialized
          fans << sup_fan.to_FanVariableVolume.get  
        end      
      end
    end 
    
    return fans
    
  end
  
  # Determine the total brake horsepower of the fans on the system
  # with or without the fans inside of fan powered terminals.
  #
  # @param include_terminal_fans [Bool] if true, power from fan powered terminals will be included
  # @param template [String] valid choices: 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
  # @return [Double] total brake horsepower of the fans on the system
  #   units = horsepower  
  def systemFanBrakeHorsepower(include_terminal_fans = true, template = "ASHRAE 90.1-2007")

    # TODO get the template from the parent model itself?
    # Or not because maybe you want to see the difference between two standards?
    OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC","#{self.name} - Determining #{template} allowable system fan power.")
  
    # Get all fans
    fans = []
    # Supply, exhaust, relief, and return fans
    fans += self.supplyReturnExhaustReliefFans
    
    # Fans inside of fan-powered terminals
    if include_terminal_fans
      self.demandComponents.each do |comp|
        if comp.to_AirTerminalSingleDuctSeriesPIUReheat.is_initialized
          term_fan = comp.to_AirTerminalSingleDuctSeriesPIUReheat.get.supplyAirFan
          if term_fan.to_FanConstantVolume.is_initialized
            fans << term_fan.to_FanConstantVolume.get
          end
        elsif comp.to_AirTerminalSingleDuctParallelPIUReheat.is_initialized
          term_fan = comp.to_AirTerminalSingleDuctParallelPIUReheat.get.fan
          if term_fan.to_FanConstantVolume.is_initialized
            fans << term_fan.to_FanConstantVolume.get
          end     
        end
      end
    end
    
    # Loop through all fans on the system and
    # sum up their brake horsepower values.
    sys_fan_bhp = 0
    fans.sort.each do |fan|
      sys_fan_bhp += fan.brakeHorsepower
    end
    
    return sys_fan_bhp
   
  end 
  
  # Set the fan pressure rises that will result in
  # the system hitting the baseline allowable fan power
  #
  # @param template [String] valid choices: 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013' 
  def setBaselineFanPressureRise(template = "ASHRAE 90.1-2007")

    OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "#{self.name} - Setting #{template} baseline fan power.")
  
    # Get the total system bhp from the proposed system, including terminal fans
    proposed_sys_bhp = self.systemFanBrakeHorsepower(true)
  
    # Get the allowable fan brake horsepower
    allowable_fan_bhp = self.allowableSystemBrakeHorsepower(template)

    # Get the fan power limitation from proposed system
    fan_pwr_adjustment_bhp = self.fanPowerLimitationPressureDropAdjustmentBrakeHorsepower
    
    # Subtract the fan power adjustment
    allowable_fan_bhp = allowable_fan_bhp - fan_pwr_adjustment_bhp
    
    # Get all fans
    fans = self.supplyReturnExhaustReliefFans    
    
    # TODO improve description
    # Loop through the fans, changing the pressure rise
    # until the fan bhp is the same percentage of the baseline allowable bhp
    # as it was on the proposed system.
    fans.each do |fan|
    
      OpenStudio::logFree(OpenStudio::Info, "#{fan.name}")
    
      # Get the bhp of the fan on the proposed system
      proposed_fan_bhp = fan.brakeHorsepower
      
      # Get the bhp of the fan on the proposed system
      proposed_fan_bhp_frac = proposed_fan_bhp / proposed_sys_bhp
      
      # Determine the target bhp of the fan on the baseline system
      baseline_fan_bhp = proposed_fan_bhp_frac * allowable_fan_bhp
      OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "* #{(baseline_fan_bhp).round(1)} bhp = Baseline fan brake horsepower.")
      
      # Set the baseline impeller eff of the fan, 
      # preserving the proposed motor eff.
      baseline_impeller_eff = fan.baselineImpellerEfficiency(template)
      fan.changeImpellerEfficiency(baseline_impeller_eff)
      OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "* #{(baseline_impeller_eff * 100).round(1)}% = Baseline fan impeller efficiency.")
      
      # Set the baseline motor efficiency for the specified bhp
      baseline_motor_eff = fan.standardMinimumMotorEfficiency(template, standards, allowable_fan_bhp)
      fan.changeMotorEfficiency(baseline_motor_eff)
      
      # Get design supply air flow rate (whether autosized or hard-sized)
      dsn_air_flow_m3_per_s = 0
      if fan.autosizedDesignSupplyAirFlowRate.is_initialized
        dsn_air_flow_m3_per_s = fan.autosizedDesignSupplyAirFlowRate.get
        dsn_air_flow_cfm = OpenStudio.convert(dsn_air_flow_m3_per_s, "m^3/s", "cfm").get
        OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "* #{dsn_air_flow_cfm.round} cfm = Autosized Design Supply Air Flow Rate.")
      else
        dsn_air_flow_m3_per_s = fan.designSupplyAirFlowRate.get
        dsn_air_flow_cfm = OpenStudio.convert(dsn_air_flow_m3_per_s, "m^3/s", "cfm").get
        OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "* #{dsn_air_flow_cfm.round} cfm = User entered Design Supply Air Flow Rate.")
      end
      
      # Determine the fan pressure rise that will result in the target bhp
      # pressure_rise_pa = fan_bhp * 746 / fan_motor_eff * fan_total_eff / dsn_air_flow_m3_per_s
      baseline_pressure_rise_pa = baseline_fan_bhp * 746 / fan.motorEfficiency * fan.fanEfficiency / dsn_air_flow_m3_per_s
      baseline_pressure_rise_in_wc = OpenStudio.convert(fan_pressure_rise_pa, "Pa", "inH_{2}O",).get
      OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "* #{(fan_pressure_rise_in_wc).round(2)} in w.c. = Pressure drop to achieve allowable fan power.")

      # Calculate the bhp of the fan to make sure it matches
      calc_bhp = fan.brakeHorsepower
      if ((calc_bhp - baseline_fan_bhp) / baseline_fan_bhp).abs > 0.02
        OpenStudio::logFree(OpenStudio::Error, "openstudio.standards.AirLoopHVAC", "#{fan.name} baseline fan bhp supposed to be #{baseline_fan_bhp}, but is #{calc_bhp}.")
      end

    end
    
    # Calculate the total bhp of the system to make sure it matches the goal
    calc_sys_bhp = self.systemFanBrakeHorsepower(false)
    if ((calc_sys_bhp - allowable_fan_bhp) / allowable_fan_bhp).abs > 0.02
      OpenStudio::logFree(OpenStudio::Error, "openstudio.standards.AirLoopHVAC", "#{self.name} baseline system bhp supposed to be #{allowable_fan_bhp}, but is #{calc_sys_bhp}.")
    end

  end

  # Get the total cooling capacity for the air loop
  #
  # @return [Double] total cooling capacity
  #   units = Watts (W)
  # @todo Change to pull water coil nominal capacity instead of design load; not a huge difference, but water coil nominal capacity not available in sizing table.
  # @todo Handle all additional cooling coil types.  Currently only handles CoilCoolingDXSingleSpeed, CoilCoolingDXTwoSpeed, and CoilCoolingWater
  def totalCoolingCapacity
  
    # Sum the cooling capacity for all cooling components
    # on the airloop, which may be inside of unitary systems.
    total_cooling_capacity_w = 0
    self.supplyComponents.each do |sc|
      # CoilCoolingDXSingleSpeed
      if sc.to_CoilCoolingDXSingleSpeed.is_initialized
        coil = sc.to_CoilCoolingDXSingleSpeed.get
        if coil.ratedTotalCoolingCapacity.is_initialized
          total_cooling_capacity_w += coil.ratedTotalCoolingCapacity.get
        elsif coil.autosizedRatedTotalCoolingCapacity.is_initialized
          total_cooling_capacity_w += coil.autosizedRatedTotalCoolingCapacity.get
        else
          OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{self.name} capacity of #{coil.name} is not available, total cooling capacity of air loop will be incorrect when applying standard.")
        end
      # CoilCoolingDXTwoSpeed
      elsif sc.to_CoilCoolingDXTwoSpeed.is_initialized  
        coil = sc.to_CoilCoolingDXTwoSpeed.get
        if coil.ratedHighSpeedTotalCoolingCapacity.is_initialized
          total_cooling_capacity_w += coil.ratedHighSpeedTotalCoolingCapacity.get
        elsif coil.autosizedRatedHighSpeedTotalCoolingCapacity.is_initialized
          total_cooling_capacity_w += coil.autosizedRatedHighSpeedTotalCoolingCapacity.get
        else
          OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{self.name} capacity of #{coil.name} is not available, total cooling capacity of air loop will be incorrect when applying standard.")
        end
      # CoilCoolingWater
      elsif sc.to_CoilCoolingWater.is_initialized
        coil = sc.to_CoilCoolingWater.get
        if coil.autosizedDesignCoilLoad.is_initialized # TODO Change to pull water coil nominal capacity instead of design load
          total_cooling_capacity_w += coil.autosizedDesignCoilLoad.get
        else
          OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{self.name} capacity of #{coil.name} is not available, total cooling capacity of air loop will be incorrect when applying standard.")
        end
      # TODO Handle all cooling coil types for economizer determination
      elsif sc.to_CoilCoolingDXMultiSpeed.is_initialized ||
            sc.to_CoilCoolingCooledBeam.is_initialized ||
            sc.to_CoilCoolingWaterToAirHeatPumpEquationFit.is_initialized ||
            sc.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.is_initialized ||
            sc.to_AirLoopHVACUnitaryHeatPumpAirToAir.is_initialized ||
            sc.to_AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed.is_initialized ||
            sc.to_AirLoopHVACUnitarySystem.is_initialized
        OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "#{self.name} has a cooling coil named #{sc.name}, whose type is not yet covered by economizer checks.")
        # CoilCoolingDXMultiSpeed
        # CoilCoolingCooledBeam
        # CoilCoolingWaterToAirHeatPumpEquationFit
        # AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass
        # AirLoopHVACUnitaryHeatPumpAirToAir	 
        # AirLoopHVACUnitaryHeatPumpAirToAirMultiSpeed	
        # AirLoopHVACUnitarySystem
      end
    end
    
    return total_cooling_capacity_w
  
  end
  
  # Determine whether or not this system
  # is required to have an economizer.
  #
  # @param template [String] valid choices: 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007', '90.1-2010', '90.1-2013'
  # @param climate_zone [String] valid choices: 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-1B', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-2B',
  # 'ASHRAE 169-2006-3A', 'ASHRAE 169-2006-3B', 'ASHRAE 169-2006-3C', 'ASHRAE 169-2006-4A', 'ASHRAE 169-2006-4B', 'ASHRAE 169-2006-4C',
  # 'ASHRAE 169-2006-5A', 'ASHRAE 169-2006-5B', 'ASHRAE 169-2006-5C', 'ASHRAE 169-2006-6A', 'ASHRAE 169-2006-6B', 'ASHRAE 169-2006-7A',
  # 'ASHRAE 169-2006-7B', 'ASHRAE 169-2006-8A', 'ASHRAE 169-2006-8B'   
  # @return [Bool] returns true if an economizer is required, false if not
  def isEconomizerRequired(template, climate_zone)
  
    economizer_required = false
    
    # A big number of btu per hr as the minimum requirement
    infinity_btu_per_hr = 999999999999
    minimum_capacity_btu_per_hr = infinity_btu_per_hr
    
    # Determine the minimum capacity that requires an economizer
    case template
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007'
      case climate_zone
      when 'ASHRAE 169-2006-1A',
        'ASHRAE 169-2006-1B',
        'ASHRAE 169-2006-2A',
        'ASHRAE 169-2006-3A',
        'ASHRAE 169-2006-4A'
        minimum_capacity_btu_per_hr = infinity_btu_per_hr # No requirement
      when 'ASHRAE 169-2006-2B',
        'ASHRAE 169-2006-5A',
        'ASHRAE 169-2006-6A',
        'ASHRAE 169-2006-7A',
        'ASHRAE 169-2006-7B',
        'ASHRAE 169-2006-8A',
        'ASHRAE 169-2006-8B'
        minimum_capacity_btu_per_hr = 35000
      when 'ASHRAE 169-2006-3B',
        'ASHRAE 169-2006-3C',
        'ASHRAE 169-2006-4B',
        'ASHRAE 169-2006-4C',
        'ASHRAE 169-2006-5B',
        'ASHRAE 169-2006-5C',
        'ASHRAE 169-2006-6B'
        minimum_capacity_btu_per_hr = 65000
      end
    when '90.1-2010', '90.1-2013'
      case climate_zone
      when 'ASHRAE 169-2006-1A',
        'ASHRAE 169-2006-1B'
        minimum_capacity_btu_per_hr = infinity_btu_per_hr # No requirement
      when 'ASHRAE 169-2006-2A',
        'ASHRAE 169-2006-3A',
        'ASHRAE 169-2006-4A',
        'ASHRAE 169-2006-2B',
        'ASHRAE 169-2006-5A',
        'ASHRAE 169-2006-6A',
        'ASHRAE 169-2006-7A',
        'ASHRAE 169-2006-7B',
        'ASHRAE 169-2006-8A',
        'ASHRAE 169-2006-8B',
        'ASHRAE 169-2006-3B',
        'ASHRAE 169-2006-3C',
        'ASHRAE 169-2006-4B',
        'ASHRAE 169-2006-4C',
        'ASHRAE 169-2006-5B',
        'ASHRAE 169-2006-5C',
        'ASHRAE 169-2006-6B'
        minimum_capacity_btu_per_hr = 54000
      end
    end
  
    # Check whether the system requires an economizer by comparing
    # the system capacity to the minimum capacity.
    minimum_capacity_w = OpenStudio.convert(minimum_capacity_btu_per_hr, "Btu/hr", "W").get
    if self.totalCoolingCapacity >= minimum_capacity_w
      economizer_required = true
    end
    
    return economizer_required
  
  end
  
  # Set the economizer limits per the standard.  Limits are based on the economizer
  # type currently specified in the ControllerOutdoorAir object on this air loop.
  #
  # @param (see #isEconomizerRequired)
  # @return [Bool] returns true if successful, false if not
  def setEconomizerLimits(template, climate_zone)
  
    # EnergyPlus economizer types
    # 'NoEconomizer'
    # 'FixedDryBulb'
    # 'FixedEnthalpy'
    # 'DifferentialDryBulb'
    # 'DifferentialEnthalpy'
    # 'FixedDewPointAndDryBulb'
    # 'ElectronicEnthalpy'
    # 'DifferentialDryBulbAndEnthalpy'  
  
    # Get the OA system and OA controller
    oa_sys = self.airLoopHVACOutdoorAirSystem
    if oa_sys.is_initialized
      oa_sys = oa_sys.get
    else
      return false # No OA system
    end
    oa_control = oa_sys.getControllerOutdoorAir
    economizer_type = oa_control.getEconomizerControlType
    
    # Return false if no economizer is present
    if economizer_type == 'NoEconomizer'
      return false
    end
  
    # Determine the limits according to the type
    drybulb_limit_f = nil
    enthalpy_limit_btu_per_lb = nil
    dewpoint_limit_f = nil
    case template
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007'
      case economizer_type
      when 'FixedDryBulb'
        case climate_zone
        when 'ASHRAE 169-2006-1B',
          'ASHRAE 169-2006-2B',
          'ASHRAE 169-2006-3B',
          'ASHRAE 169-2006-3C',
          'ASHRAE 169-2006-4B',
          'ASHRAE 169-2006-4C',
          'ASHRAE 169-2006-5B',
          'ASHRAE 169-2006-5C',
          'ASHRAE 169-2006-6B',
          'ASHRAE 169-2006-7B',
          'ASHRAE 169-2006-8A',
          'ASHRAE 169-2006-8B'
          drybulb_limit_f = 75
        when 'ASHRAE 169-2006-5A',
          'ASHRAE 169-2006-6A',
          'ASHRAE 169-2006-7A'
          drybulb_limit_f = 70
        when 'ASHRAE 169-2006-1A',
          'ASHRAE 169-2006-2A',
          'ASHRAE 169-2006-3A',
          'ASHRAE 169-2006-4A'
          drybulb_limit_f = 65
        end
      when 'FixedEnthalpy'
        enthalpy_limit_btu_per_lb = 28
      when 'FixedDewPointAndDryBulb'
        drybulb_limit_f = 75
        dewpoint_limit_f = 55
      end
    when '90.1-2010', '90.1-2013'
      case economizer_type
      when 'FixedDryBulb'
        case climate_zone
        when 'ASHRAE 169-2006-1B',
          'ASHRAE 169-2006-2B',
          'ASHRAE 169-2006-3B',
          'ASHRAE 169-2006-3C',
          'ASHRAE 169-2006-4B',
          'ASHRAE 169-2006-4C',
          'ASHRAE 169-2006-5B',
          'ASHRAE 169-2006-5C',
          'ASHRAE 169-2006-6B',
          'ASHRAE 169-2006-7A',
          'ASHRAE 169-2006-7B',
          'ASHRAE 169-2006-8A',
          'ASHRAE 169-2006-8B'
          drybulb_limit_f = 75
        when 'ASHRAE 169-2006-5A',
          'ASHRAE 169-2006-6A'
          drybulb_limit_f = 70
        end
      when 'FixedEnthalpy'
        enthalpy_limit_btu_per_lb = 28
      when 'FixedDewPointAndDryBulb'
        drybulb_limit_f = 75
        dewpoint_limit_f = 55
      end
    end 
 
    # Set the limits
    case economizer_type
    when 'FixedDryBulb'
      if drybulb_limit_f
        drybulb_limit_c = OpenStudio.convert(drybulb_limit_f, 'F', 'C').get
        oa_control.setEconomizerMaximumLimitDryBulbTemperature(drybulb_limit_c)
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{template} #{climate_zone}:  #{self.name}: Economizer type = #{economizer_type}, dry bulb limit = #{drybulb_limit_f}F")
      end
    when 'FixedEnthalpy'
      if enthalpy_limit_btu_per_lb
        enthalpy_limit_j_per_kg = OpenStudio.convert(enthalpy_limit_btu_per_lb, 'Btu/lb', 'J/kg').get
        oa_control.setEconomizerMaximumLimitEnthalpy(enthalpy_limit_j_per_kg)
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{template} #{climate_zone}:  #{self.name}: Economizer type = #{economizer_type}, enthalpy limit = #{enthalpy_limit_btu_per_lb}Btu/lb")
      end
    when 'FixedDewPointAndDryBulb'
      if drybulb_limit_f && dewpoint_limit_f
        drybulb_limit_c = OpenStudio.convert(drybulb_limit_f, 'F', 'C').get
        dewpoint_limit_c = OpenStudio.convert(dewpoint_limit_f, 'F', 'C').get
        oa_control.setEconomizerMaximumLimitDryBulbTemperature(drybulb_limit_c)
        oa_control.setEconomizerMaximumLimitDewpointTemperature(dewpoint_limit_c)
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{template} #{climate_zone}:  #{self.name}: Economizer type = #{economizer_type}, dry bulb limit = #{drybulb_limit_f}F, dew-point limit = #{dewpoint_limit_f}F")
      end
    end 

    return true
    
  end

  # For systems required to have an economizer, set the economizer
  # to integrated on non-integrated per the standard.
  #
  # @note this method assumes you previously checked that an economizer is required at all
  #   via #isEconomizerRequired
  # @param (see #isEconomizerRequired)
  # @return [Bool] returns true if successful, false if not
  def setEconomizerIntegration(template, climate_zone)
  
    # Determine if the system is a VAV system based on the fan
    # which may be inside of a unitary system.
    is_vav = false
    self.supplyComponents.reverse.each do |comp|
      if comp.to_FanVariableVolume.is_initialized
        is_vav = true
      elsif comp.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.is_initialized
        fan = comp.to_AirLoopHVACUnitaryHeatCoolVAVChangeoverBypass.get.supplyAirFan
        if fan.to_FanVariableVolume.is_initialized
          is_vav = true
        end
      elsif comp.to_AirLoopHVACUnitarySystem.is_initialized
        fan = comp.to_AirLoopHVACUnitarySystem.get.supplyFan
        if fan.is_initialized
          if fan.get.to_FanVariableVolume.is_initialized
            is_vav = true
          end
        end
      end  
    end

    # Determine the number of zones the system serves
    num_zones_served = self.thermalZones.size
    
    # A big number of btu per hr as the minimum requirement
    infinity_btu_per_hr = 999999999999
    minimum_capacity_btu_per_hr = infinity_btu_per_hr
    
    # Determine if an integrated economizer is required
    integrated_economizer_required = true
    case template
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007'    
      minimum_capacity_btu_per_hr = 65000
      minimum_capacity_w = OpenStudio.convert(minimum_capacity_btu_per_hr, "Btu/hr", "W").get
      # 6.5.1.3 Integrated Economizer Control
      # Exception a, DX VAV systems
      if is_vav == true && num_zones_served > 1
        integrated_economizer_required = false
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{template} #{climate_zone}:  #{self.name}: non-integrated economizer per 6.5.1.3 exception a, DX VAV system.")
      # Exception b, DX units less than 65,000 Btu/hr
      elsif self.totalCoolingCapacity < minimum_capacity_w
        integrated_economizer_required = false
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{template} #{climate_zone}:  #{self.name}: non-integrated economizer per 6.5.1.3 exception b, DX system less than #{minimum_capacity_btu_per_hr}Btu/hr.")
      else
        # Exception c, Systems in climate zones 1,2,3a,4a,5a,5b,6,7,8
        case climate_zone
        when 'ASHRAE 169-2006-1A',
          'ASHRAE 169-2006-1B',
          'ASHRAE 169-2006-2A',
          'ASHRAE 169-2006-2B',
          'ASHRAE 169-2006-3A',
          'ASHRAE 169-2006-4A',
          'ASHRAE 169-2006-5A',
          'ASHRAE 169-2006-5B',
          'ASHRAE 169-2006-6A',
          'ASHRAE 169-2006-6B',
          'ASHRAE 169-2006-7A',
          'ASHRAE 169-2006-7B',
          'ASHRAE 169-2006-8A',
          'ASHRAE 169-2006-8B'
          integrated_economizer_required = false
          OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{template} #{climate_zone}:  #{self.name}: non-integrated economizer per 6.5.1.3 exception c, climate zone #{climate_zone}.")
        when 'ASHRAE 169-2006-3B',
          'ASHRAE 169-2006-3C',
          'ASHRAE 169-2006-4B',
          'ASHRAE 169-2006-4C',
          'ASHRAE 169-2006-5C'
          integrated_economizer_required = true
        end
      end
    when '90.1-2010', '90.1-2013'
      integrated_economizer_required = true
    end
  
    # Get the OA system and OA controller
    oa_sys = self.airLoopHVACOutdoorAirSystem
    if oa_sys.is_initialized
      oa_sys = oa_sys.get
    else
      return false # No OA system
    end
    oa_control = oa_sys.getControllerOutdoorAir  
  
    # Apply integrated or non-integrated economizer
    if integrated_economizer_required
      oa_control.setLockoutType('NoLockout')
    else
      oa_control.setLockoutType('LockoutWithCompressor')
    end

    return true
    
  end
  
  # Add economizer to the airloop per Appendix G baseline
  #
  # @param (see #isEconomizerRequired)
  # @return [Bool] returns true if successful, false if not
  # @todo This method is not yet functional
  def addBaselineEconomizer(template, climate_zone)
  
  end
  
  # Check the economizer type currently specified in the ControllerOutdoorAir object on this air loop
  # is acceptable per the standard.
  #
  # @param (see #isEconomizerRequired)
  # @return [Bool] Returns true if allowable, if the system has no economizer or no OA system.
  # Returns false if the economizer type is not allowable.
  def isEconomizerTypeAllowable(template, climate_zone)
  
    # EnergyPlus economizer types
    # 'NoEconomizer'
    # 'FixedDryBulb'
    # 'FixedEnthalpy'
    # 'DifferentialDryBulb'
    # 'DifferentialEnthalpy'
    # 'FixedDewPointAndDryBulb'
    # 'ElectronicEnthalpy'
    # 'DifferentialDryBulbAndEnthalpy'
    
    # Get the OA system and OA controller
    oa_sys = self.airLoopHVACOutdoorAirSystem
    if oa_sys.is_initialized
      oa_sys = oa_sys.get
    else
      return true # No OA system
    end
    oa_control = oa_sys.getControllerOutdoorAir
    economizer_type = oa_control.getEconomizerControlType
    
    # Return true if no economizer is present
    if economizer_type == 'NoEconomizer'
      return true
    end
    
    # Determine the minimum capacity that requires an economizer
    prohibited_types = []
    case template
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007'
      case climate_zone
      when 'ASHRAE 169-2006-1B',
        'ASHRAE 169-2006-2B',
        'ASHRAE 169-2006-3B',
        'ASHRAE 169-2006-3C',
        'ASHRAE 169-2006-4B',
        'ASHRAE 169-2006-4C',
        'ASHRAE 169-2006-5B',
        'ASHRAE 169-2006-6B',
        'ASHRAE 169-2006-7A',
        'ASHRAE 169-2006-7B',
        'ASHRAE 169-2006-8A',
        'ASHRAE 169-2006-8B'
        prohibited_types = ['FixedEnthalpy']
      when
        'ASHRAE 169-2006-1A',
        'ASHRAE 169-2006-2A',
        'ASHRAE 169-2006-3A',
        'ASHRAE 169-2006-4A'
        prohibited_types = ['DifferentialDryBulb']
      when 
        'ASHRAE 169-2006-5A',
        'ASHRAE 169-2006-6A',
        prohibited_types = []
      end
    when  '90.1-2010', '90.1-2013'
      case climate_zone
      when 'ASHRAE 169-2006-1B',
        'ASHRAE 169-2006-2B',
        'ASHRAE 169-2006-3B',
        'ASHRAE 169-2006-3C',
        'ASHRAE 169-2006-4B',
        'ASHRAE 169-2006-4C',
        'ASHRAE 169-2006-5B',
        'ASHRAE 169-2006-6B',
        'ASHRAE 169-2006-7A',
        'ASHRAE 169-2006-7B',
        'ASHRAE 169-2006-8A',
        'ASHRAE 169-2006-8B'
        prohibited_types = ['FixedEnthalpy']
      when
        'ASHRAE 169-2006-1A',
        'ASHRAE 169-2006-2A',
        'ASHRAE 169-2006-3A',
        'ASHRAE 169-2006-4A'
        prohibited_types = ['FixedDryBulb', 'DifferentialDryBulb']
      when 
        'ASHRAE 169-2006-5A',
        'ASHRAE 169-2006-6A',
        prohibited_types = []
      end
    end
    
    # Check if the specified type is allowed
    economizer_type_allowed = true
    if prohibited_types.include?(economizer_type)
      economizer_type_allowed = false
    end
    
    return economizer_type_allowed
  
  end
  
  # Check if ERV is required on this airloop.
  #
  # @param (see #isEconomizerRequired)
  # @return [Bool] Returns true if required, false if not.  
  # @todo Add exception logic for systems serving parking garage, warehouse, or multifamily
  def isEnergyRecoveryVentilatorRequired(template, climate_zone)
      
    # ERV Not Applicable for AHUs that serve 
    # parking garage, warehouse, or multifamily
    # if space_types_served_names.include?('PNNL_Asset_Rating_Apartment_Space_Type') ||
    # space_types_served_names.include?('PNNL_Asset_Rating_LowRiseApartment_Space_Type') ||
    # space_types_served_names.include?('PNNL_Asset_Rating_ParkingGarage_Space_Type') ||
    # space_types_served_names.include?('PNNL_Asset_Rating_Warehouse_Space_Type')
      # OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "For #{self.name}, ERV not applicable because it because it serves parking garage, warehouse, or multifamily.")
      # return false
    # end
    
    # ERV Not Applicable for AHUs that have DCV
    # or that have no OA intake.    
    controller_oa = nil
    controller_mv = nil
    oa_system = nil
    if self.airLoopHVACOutdoorAirSystem.is_initialized
      oa_system = self.airLoopHVACOutdoorAirSystem.get
      controller_oa = oa_system.getControllerOutdoorAir      
      controller_mv = controller_oa.controllerMechanicalVentilation
      if controller_mv.demandControlledVentilation == true
        OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "For #{template} #{self.name}, ERV not applicable because DCV enabled.")
        runner.registerInfo()
        return false
      end
    else
      OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "For #{template} #{self.name}, ERV not applicable because it has no OA intake.")
      return false
    end

    # Get the AHU design supply air flow rate
    dsn_flow_m3_per_s = nil
    if self.designSupplyAirFlowRate.is_initialized
      dsn_flow_m3_per_s = self.designSupplyAirFlowRate.get
    elsif self.autosizedDesignSupplyAirFlowRate.is_initialized
      dsn_flow_m3_per_s = self.autosizedDesignSupplyAirFlowRate.get
    else
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.AirLoopHVAC", "For #{template} #{self.name} design supply air flow rate is not available, cannot apply efficiency standard.")
      return false
    end
    dsn_flow_cfm = OpenStudio.convert(dsn_flow_m3_per_s, 'm^3/s', 'cfm').get
    
    # Get the minimum OA flow rate
    min_oa_flow_m3_per_s = nil
    if controller_oa.minimumOutdoorAirFlowRate.is_initialized
      min_oa_flow_m3_per_s = controller_oa.minimumOutdoorAirFlowRate.get
    elsif controller_oa.autosizedMinimumOutdoorAirFlowRate.is_initialized
      min_oa_flow_m3_per_s = controller_oa.autosizedMinimumOutdoorAirFlowRate.get
    else
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.AirLoopHVAC", "For #{template} #{controller_oa.name} minimum OA flow rate is not available, cannot apply efficiency standard.")
      return false
    end
    min_oa_flow_cfm = OpenStudio.convert(min_oa_flow_m3_per_s, 'm^3/s', 'cfm').get
    
    # Calculate the percent OA at design airflow
    pct_oa = min_oa_flow_m3_per_s/dsn_flow_m3_per_s
    
    case template
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004'
      erv_cfm = nil # Not required
    when '90.1-2004', '90.1-2007'
      if pct_oa < 0.7
        erv_cfm = nil
      else
        erv_cfm = 5000
      end
    when '90.1-2010'
      # Table 6.5.6.1
      case climate_zone
      when 'ASHRAE 169-2006-3B', 'ASHRAE 169-2006-3C', 'ASHRAE 169-2006-4B', 'ASHRAE 169-2006-4C', 'ASHRAE 169-2006-5B'
        if pct_oa < 0.3
          erv_cfm = nil
        elsif pct_oa >= 0.3 && pct_oa < 0.4
          erv_cfm = nil
        elsif pct_oa >= 0.4 && pct_oa < 0.5
          erv_cfm = nil
        elsif pct_oa >= 0.5 && pct_oa < 0.6
          erv_cfm = nil
        elsif pct_oa >= 0.6 && pct_oa < 0.7
          erv_cfm = nil
        elsif pct_oa >= 0.7 && pct_oa < 0.8
          erv_cfm = 5000
        elsif pct_oa >= 0.8 
          erv_cfm = 5000
        end
      when 'ASHRAE 169-2006-1B', 'ASHRAE 169-2006-2B', 'ASHRAE 169-2006-5C'
        if pct_oa < 0.3
          erv_cfm = nil
        elsif pct_oa >= 0.3 && pct_oa < 0.4
          erv_cfm = nil
        elsif pct_oa >= 0.4 && pct_oa < 0.5
          erv_cfm = nil
        elsif pct_oa >= 0.5 && pct_oa < 0.6
          erv_cfm = 26000
        elsif pct_oa >= 0.6 && pct_oa < 0.7
          erv_cfm = 12000
        elsif pct_oa >= 0.7 && pct_oa < 0.8
          erv_cfm = 5000
        elsif pct_oa >= 0.8 
          erv_cfm = 4000
        end
      when 'ASHRAE 169-2006-6B'
        if pct_oa < 0.3
          erv_cfm = nil
        elsif pct_oa >= 0.3 && pct_oa < 0.4
          erv_cfm = 11000
        elsif pct_oa >= 0.4 && pct_oa < 0.5
          erv_cfm = 5500
        elsif pct_oa >= 0.5 && pct_oa < 0.6
          erv_cfm = 4500
        elsif pct_oa >= 0.6 && pct_oa < 0.7
          erv_cfm = 3500
        elsif pct_oa >= 0.7 && pct_oa < 0.8
          erv_cfm = 2500
        elsif pct_oa >= 0.8 
          erv_cfm = 1500
        end      
      when 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-3A', 'ASHRAE 169-2006-4A', 'ASHRAE 169-2006-5A', 'ASHRAE 169-2006-6A'
        if pct_oa < 0.3
          erv_cfm = nil
        elsif pct_oa >= 0.3 && pct_oa < 0.4
          erv_cfm = 5500
        elsif pct_oa >= 0.4 && pct_oa < 0.5
          erv_cfm = 4500
        elsif pct_oa >= 0.5 && pct_oa < 0.6
          erv_cfm = 3500
        elsif pct_oa >= 0.6 && pct_oa < 0.7
          erv_cfm = 2000
        elsif pct_oa >= 0.7 && pct_oa < 0.8
          erv_cfm = 1000
        elsif pct_oa >= 0.8 
          erv_cfm = 0
        end   
      when 'ASHRAE 169-2006-7A', 'ASHRAE 169-2006-7B', 'ASHRAE 169-2006-8A', 'ASHRAE 169-2006-8B'
        if pct_oa < 0.3
          erv_cfm = nil
        elsif pct_oa >= 0.3 && pct_oa < 0.4
          erv_cfm = 2500
        elsif pct_oa >= 0.4 && pct_oa < 0.5
          erv_cfm = 1000
        elsif pct_oa >= 0.5 && pct_oa < 0.6
          erv_cfm = 0
        elsif pct_oa >= 0.6 && pct_oa < 0.7
          erv_cfm = 0
        elsif pct_oa >= 0.7 && pct_oa < 0.8
          erv_cfm = 0
        elsif pct_oa >= 0.8 
          erv_cfm = 0
        end      
      end
    when '90.1-2013'
      # Table 6.5.6.1-2
      case climate_zone
      when 'ASHRAE 169-2006-3C'
        erv_cfm = nil
      when 'ASHRAE 169-2006-1B', 'ASHRAE 169-2006-2B', 'ASHRAE 169-2006-3B', 'ASHRAE 169-2006-4C', 'ASHRAE 169-2006-5C'
        if pct_oa < 0.1
          erv_cfm = nil
        elsif pct_oa >= 0.1 && pct_oa < 0.2
          erv_cfm = nil
        elsif pct_oa >= 0.2 && pct_oa < 0.3
          erv_cfm = 19500
        elsif pct_oa >= 0.3 && pct_oa < 0.4
          erv_cfm = 9000
        elsif pct_oa >= 0.4 && pct_oa < 0.5
          erv_cfm = 5000
        elsif pct_oa >= 0.5 && pct_oa < 0.6
          erv_cfm = 4000
        elsif pct_oa >= 0.6 && pct_oa < 0.7
          erv_cfm = 3000
        elsif pct_oa >= 0.7 && pct_oa < 0.8
          erv_cfm = 1500
        elsif pct_oa >= 0.8 
          erv_cfm = 0
        end
      when 'ASHRAE 169-2006-1A', 'ASHRAE 169-2006-2A', 'ASHRAE 169-2006-3A', 'ASHRAE 169-2006-4B',  'ASHRAE 169-2006-5B'
        if pct_oa < 0.1
          erv_cfm = nil
        elsif pct_oa >= 0.1 && pct_oa < 0.2
          erv_cfm = 2500
        elsif pct_oa >= 0.2 && pct_oa < 0.3
          erv_cfm = 2000
        elsif pct_oa >= 0.3 && pct_oa < 0.4
          erv_cfm = 1000
        elsif pct_oa >= 0.4 && pct_oa < 0.5
          erv_cfm = 500
        elsif pct_oa >= 0.5
          erv_cfm = 0
        end
      when 'ASHRAE 169-2006-4A', 'ASHRAE 169-2006-5A', 'ASHRAE 169-2006-6A', 'ASHRAE 169-2006-6B', 'ASHRAE 169-2006-7A', 'ASHRAE 169-2006-7B', 'ASHRAE 169-2006-8A', 'ASHRAE 169-2006-8B'
        if pct_oa < 0.1
          erv_cfm = nil
        elsif pct_oa >= 0.1
          erv_cfm = 0
        end
      end
    end
    
    # Determine if an ERV is required
    erv_required = nil
    if erv_cfm.nil?
      OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "For #{template} #{self.name}, ERV not required based on #{(pct_oa*100).round}% OA flow, design flow of #{dsn_flow_cfm.round}cfm, and climate zone #{climate_zone}.")
      erv_required = false 
    elsif dsn_flow_cfm < erv_cfm
      OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "For #{template} #{self.name}, ERV not required based on #{(pct_oa*100).round}% OA flow, design flow of #{dsn_flow_cfm.round}cfm, and climate zone #{climate_zone}. Does not exceed minimum flow requirement of #{erv_cfm}cfm.")
      erv_required = false 
    else
      OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "For #{template} #{self.name}, ERV required based on #{(pct_oa*100).round}% OA flow, design flow of #{dsn_flow_cfm.round}cfm, and climate zone #{climate_zone}. Exceeds minimum flow requirement of #{erv_cfm}cfm.")
      erv_required = true 
    end
  
    return erv_required
  
  end  
   
  # Determine if multizone vav optimization is required.
  #
  # @param (see #isEconomizerRequired)
  # @return [Bool] Returns true if required, false if not.  
  # @todo Add exception logic for 
  #   systems with AIA healthcare ventilation requirements
  #   dual duct systems
  def is_multizone_vav_optimization_required(template, climate_zone)

    multizone_opt_required = false
  
    case template
    when 'DOE Ref Pre-1980', 'DOE Ref 1980-2004', '90.1-2004', '90.1-2007'
      
      # Not required before 90.1-2010
      return multizone_opt_required
      
    when '90.1-2010', '90.1-2013'
      
      # Not required for systems with fan-powered terminals
      num_fan_powered_terminals = 0
      self.demandComponents.each do |comp|
        if comp.to_AirTerminalSingleDuctParallelPIUReheat.is_initialized || comp.to_AirTerminalSingleDuctSeriesPIUReheat.is_initialized 
          num_fan_powered_terminals += 1
        end
      end
      if num_fan_powered_terminals > 0
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.AirLoopHVAC", "For #{template} #{climate_zone}:  #{self.name}, multizone vav optimization is not required because the system has #{num_fan_powered_terminals} fan-powered terminals.")
        return multizone_opt_required
      end
      
      # Not required for systems that require an ERV
      if self.isEnergyRecoveryVentilatorRequired(template, climate_zone)
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{template} #{climate_zone}:  #{self.name}: multizone vav optimization is not required because the system has Energy Recovery.")
        return multizone_opt_required
      end
      
      # Get the OA intake
      controller_oa = nil
      controller_mv = nil
      oa_system = nil
      if self.airLoopHVACOutdoorAirSystem.is_initialized
        oa_system = self.airLoopHVACOutdoorAirSystem.get
        controller_oa = oa_system.getControllerOutdoorAir      
        controller_mv = controller_oa.controllerMechanicalVentilation
      else
        OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "For #{template} #{self.name}, multizone optimization is not applicable because system has no OA intake.")
        return multizone_opt_required
      end
      
      # Get the AHU design supply air flow rate
      dsn_flow_m3_per_s = nil
      if self.designSupplyAirFlowRate.is_initialized
        dsn_flow_m3_per_s = self.designSupplyAirFlowRate.get
      elsif self.autosizedDesignSupplyAirFlowRate.is_initialized
        dsn_flow_m3_per_s = self.autosizedDesignSupplyAirFlowRate.get
      else
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.AirLoopHVAC", "For #{template} #{self.name} design supply air flow rate is not available, cannot apply efficiency standard.")
        return multizone_opt_required
      end
      dsn_flow_cfm = OpenStudio.convert(dsn_flow_m3_per_s, 'm^3/s', 'cfm').get
    
      # Get the minimum OA flow rate
      min_oa_flow_m3_per_s = nil
      if controller_oa.minimumOutdoorAirFlowRate.is_initialized
        min_oa_flow_m3_per_s = controller_oa.minimumOutdoorAirFlowRate.get
      elsif controller_oa.autosizedMinimumOutdoorAirFlowRate.is_initialized
        min_oa_flow_m3_per_s = controller_oa.autosizedMinimumOutdoorAirFlowRate.get
      else
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.AirLoopHVAC", "For #{template} #{controller_oa.name} minimum OA flow rate is not available, cannot apply efficiency standard.")
        return multizone_opt_required
      end
      min_oa_flow_cfm = OpenStudio.convert(min_oa_flow_m3_per_s, 'm^3/s', 'cfm').get
    
      # Calculate the percent OA at design airflow
      pct_oa = min_oa_flow_m3_per_s/dsn_flow_m3_per_s
    
      # Not required for systems where
      # exhaust is more than 70% of the total OA intake.
      if pct_oa > 0.7
        OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.AirLoopHVAC", "For #{template} #{controller_oa.name} multizone optimization is not applicable because system is more than 70% OA.")
        return multizone_opt_required
      end

      # TODO Not required for dual-duct systems
      # if self.isDualDuct
        # OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.AirLoopHVAC", "For #{template} #{controller_oa.name} multizone optimization is not applicable because it is a dual duct system")
        # return multizone_opt_required
      # end
      
      # If here, multizone vav optimization is required
      multizone_opt_required = true
      
      return multizone_opt_required
    
    end
   
  end      
   
  # Enable multizone vav optimization by changing the Outdoor Air Method
  # in the Controller:MechanicalVentilation object to 'VentilationRateProcedure'
  #
  # @return [Bool] Returns true if required, false if not.  
  def enable_multizone_vav_optimization
   
    # Enable multizone vav optimization
    # at each timestep.
    if self.airLoopHVACOutdoorAirSystem.is_initialized
      oa_system = self.airLoopHVACOutdoorAirSystem.get
      controller_oa = oa_system.getControllerOutdoorAir      
      controller_mv = controller_oa.controllerMechanicalVentilation
      controller_mv.setSystemOutdoorAirMethod('VentilationRateProcedure')
    else
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.AirLoopHVAC", "For #{self.name}, cannot enable multizone vav optimization because the system has no OA intake.")
      return false
    end
   
  end 
   
  # Disable multizone vav optimization by changing the Outdoor Air Method
  # in the Controller:MechanicalVentilation object to 'ZoneSum'
  #
  # @return [Bool] Returns true if required, false if not.
  def disable_multizone_vav_optimization
   
    # Disable multizone vav optimization
    # at each timestep.
    if self.airLoopHVACOutdoorAirSystem.is_initialized
      oa_system = self.airLoopHVACOutdoorAirSystem.get
      controller_oa = oa_system.getControllerOutdoorAir      
      controller_mv = controller_oa.controllerMechanicalVentilation
      controller_mv.setSystemOutdoorAirMethod('ZoneSum')
    else
      OpenStudio::logFree(OpenStudio::Warn, "openstudio.standards.AirLoopHVAC", "For #{self.name}, cannot disable multizone vav optimization because the system has no OA intake.")
      return false
    end
   
  end 

  # Set the minimum VAV damper positions to the values
  #
  # @param (see #isEconomizerRequired)
  # @return [Bool] Returns true if required, false if not.  
  # @todo Add exception logic for systems serving parking garage, warehouse, or multifamily
  def set_minimum_vav_damper_positions
   
    # Total uncorrected outdoor airflow rate
    v_ou = 0.0
    self.thermalZones.each do |zone|
      v_ou += zone.outdoor_airflow_rate
    end
    
    # System primary airflow rate (whether autosized or hard-sized)
    v_ps = 0.0
    if self.autosizedDesignSupplyAirFlowRate.is_initialized
      v_ps = self.autosizedDesignSupplyAirFlowRate.get
    else
      v_ps = self.designSupplyAirFlowRate.get
    end 
    
    # Average outdoor air fraction
    x_s = v_ou / v_ps
    
    # Determine the zone ventilation effectiveness
    # for every zone on the system.
    # When ventilation effectiveness is too low,
    # increase the minimum damper position.
    e_vzs = []
    e_vzs_adj = []
    num_zones_adj = 0
    self.thermalZones.each do |zone|
      
      # Breathing zone airflow rate
      v_bz = zone.outdoor_airflow_rate 
      
      # Zone air distribution, assumed 1 per PNNL
      e_z = 1.0 
      
      # Zone airflow rate
      v_oz = v_bz / e_z 
      
      # Primary design airflow rate
      # max of heating and cooling 
      # design air flow rates
      v_pz = 0.0
      clg_dsn_flow = zone.autosizedCoolingDesignAirFlowRate
      if clg_dsn_flow.is_initialized
        clg_dsn_flow = clg_dsn_flow.get
        if clg_dsn_flow > v_pz
          v_pz = clg_dsn_flow
        end
      end
      htg_dsn_flow = zone.autosizedHeatingDesignAirFlowRate
      if htg_dsn_flow.is_initialized
        htg_dsn_flow = htg_dsn_flow.get
        if htg_dsn_flow > v_pz
          v_pz = htg_dsn_flow
        end
      end
      
      # Get the minimum damper position
      mdp = 1.0
      zone.equipment.each do |equip|
        if equip.to_AirTerminalSingleDuctVAVHeatAndCoolNoReheat.is_initialized
          term = equip.to_AirTerminalSingleDuctVAVHeatAndCoolNoReheat.get
          mdp = term.zoneMinimumAirFlowFraction
        elsif equip.to_AirTerminalSingleDuctVAVHeatAndCoolReheat.is_initialized
          term = equip.to_AirTerminalSingleDuctVAVHeatAndCoolReheat.get
          mdp = term.zoneMinimumAirFlowFraction
        elsif equip.to_AirTerminalSingleDuctVAVNoReheat.is_initialized
          term = equip.to_AirTerminalSingleDuctVAVNoReheat.get
          if term.constantMinimumAirFlowFraction.is_initialized
            mdp = term.constantMinimumAirFlowFraction.get
          end
        elsif equip.to_AirTerminalSingleDuctVAVReheat.is_initialized
          term = equip.to_AirTerminalSingleDuctVAVReheat.get
          mdp = term.constantMinimumAirFlowFraction
        end
      end
    
      # Zone minimum discharge airflow rate
      v_dz = v_pz * mdp
    
      # Zone discharge air fraction
      z_d = v_oz / v_dz
      
      # Zone ventilation effectiveness
      e_vz = 1 + x_s - z_d
    
      # Store the ventilation effectiveness
      e_vzs << e_vz
    
      # Check the ventilation effectiveness against
      # the minimum limit per PNNL and increase
      # as necessary.
      if e_vz < 0.6
      
        # Adjusted discharge air fraction
        z_d_adj = 1 + x_s - 0.6
        
        # Adjusted min discharge airflow rate
        v_dz_adj = v_oz / z_d_adj
      
        # Adjusted minimum damper position
        mdp_adj = v_dz_adj / v_pz
        
        # Don't allow values > 1
        if mdp_adj > 1.0
          mdp_adj = 1.0
        end
        
        # Zone ventilation effectiveness
        e_vz_adj = 1 + x_s - z_d_adj
    
        # Store the ventilation effectiveness
        e_vzs_adj << e_vz_adj
        
        # Set the adjusted minimum damper position
        zone.equipment.each do |equip|
          if equip.to_AirTerminalSingleDuctVAVHeatAndCoolNoReheat.is_initialized
            term = equip.to_AirTerminalSingleDuctVAVHeatAndCoolNoReheat.get
            term.setZoneMinimumAirFlowFraction(mdp_adj)
          elsif equip.to_AirTerminalSingleDuctVAVHeatAndCoolReheat.is_initialized
            term = equip.to_AirTerminalSingleDuctVAVHeatAndCoolReheat.get
            term.setZoneMinimumAirFlowFraction(mdp_adj)
          elsif equip.to_AirTerminalSingleDuctVAVNoReheat.is_initialized
            term = equip.to_AirTerminalSingleDuctVAVNoReheat.get
            term.setConstantMinimumAirFlowFraction(mdp_adj)
          elsif equip.to_AirTerminalSingleDuctVAVReheat.is_initialized
            term = equip.to_AirTerminalSingleDuctVAVReheat.get
            term.setConstantMinimumAirFlowFraction(mdp_adj)
          end
        end
        
        num_zones_adj += 1
        
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For: #{self.name}: Zone #{zone.name} has a ventilation effectiveness of #{e_vz.round(2)}.  Increasing to #{e_vz_adj} by increasing minimum damper position from #{mdp.round(2)} to #{mdp_adj.round(2)}.")

      else
        # Store the unadjusted value
        e_vzs_adj << e_vz
      end
  
    end
  
    # Min system zone ventilation effectiveness
    e_v = e_vzs.min
   
    # Total system outdoor intake flow rate 
    v_ot = v_ou / e_v
    
    # Min system zone ventilation effectiveness
    e_v_adj = e_vzs_adj.min
   
    # Total system outdoor intake flow rate 
    v_ot_adj = v_ou / e_v_adj
    
    if num_zones_adj > 0
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For:  #{self.name}: #{num_zones_adj} zones had minimum damper position increased to meet ventilation requirements.  Original system ventilation effectiveness was #{e_v.round(2)}.  After adjustment, system ventilation effectiveness is #{e_v_adj.round(2)}")
    end
   
    return true
   
  end
   
  # Determine if demand control ventilation (DCV) is
  # required for this air loop.
  #
  # @param (see #isEconomizerRequired)
  # @return [Bool] Returns true if required, false if not.  
  # @todo Add exception logic for 
  #   systems that serve multifamily, parking garage, warehouse
  def is_demand_control_ventilation_required(template, climate_zone)
   
    dcv_required = false
   
    # Not required by the old vintages
    if template == 'DOE Ref Pre-1980' || template == 'DOE Ref 1980-2004'
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{template} #{climate_zone}:  #{self.name}: DCV is not required for any system.")
      return dcv_required
    end
   
    # Not required for systems that require an ERV
    if self.isEnergyRecoveryVentilatorRequired(template, climate_zone)
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{template} #{climate_zone}:  #{self.name}: DCV is not required since the system is required to have Energy Recovery.")
      return dcv_required
    end
   
    # Area, occupant density, and OA flow limits
    min_area_ft2 = 0
    min_occ_per_1000_ft2 = 0
    min_oa_without_economizer_cfm = 0
    min_oa_with_economizer_cfm = 0
    case template
    when '90.1-2004'
      min_area_ft2 = 0
      min_occ_per_1000_ft2 = 100
      min_oa_without_economizer_cfm = 3000
      min_oa_with_economizer_cfm = 0
    when '90.1-2007', '90.1-2010'
      min_area_ft2 = 500
      min_occ_per_1000_ft2 = 40
      min_oa_without_economizer_cfm = 3000
      min_oa_with_economizer_cfm = 1200
    when '90.1-2013'
      min_area_ft2 = 500
      min_occ_per_1000_ft2 = 25
      min_oa_without_economizer_cfm = 3000
      min_oa_with_economizer_cfm = 750
    end
    
    # Get the area served and the number of occupants
    area_served_m2 = 0
    num_people = 0
    self.thermalZones.each do |zone|
      zone.spaces.each do |space|
        area_served_m2 += space.floorArea
        num_people += space.numberOfPeople
      end
    end

    # Check the minimum area
    area_served_ft2 = OpenStudio.convert(area_served_m2, 'm^2', 'ft^2').get
    if area_served_ft2 < min_area_ft2
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{template} #{climate_zone}:  #{self.name}: DCV is not required since the system serves #{area_served_ft2.round} ft2, but the minimum size is #{min_area_ft2.round} ft2.")
      return dcv_required
    end
    
    # Check the minimum occupancy density
    occ_per_ft2 = num_people / area_served_ft2
    occ_per_1000_ft2 = occ_per_ft2 * 1000
    if occ_per_1000_ft2 < min_occ_per_1000_ft2
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{template} #{climate_zone}:  #{self.name}: DCV is not required since the system occupant density is #{occ_per_1000_ft2.round} people/1000 ft2, but the minimum occupant density is #{min_occ_per_1000_ft2.round} people/1000 ft2.")
      return dcv_required
    end
    
    # Get the min OA flow rate   
    oa_flow_m3_per_s = 0
    if self.airLoopHVACOutdoorAirSystem.is_initialized
      oa_system = self.airLoopHVACOutdoorAirSystem.get
      controller_oa = oa_system.getControllerOutdoorAir      
      if controller_oa.minimumOutdoorAirFlowRate.is_initialized
        oa_flow_m3_per_s = controller_oa.minimumOutdoorAirFlowRate.get
      elsif controller_oa.autosizedMinimumOutdoorAirFlowRate.is_initialized
        oa_flow_m3_per_s = controller_oa.autosizedMinimumOutdoorAirFlowRate.get
      end
    else
      OpenStudio::logFree(OpenStudio::Info, "openstudio.standards.AirLoopHVAC", "For #{template} #{self.name}, DCV not applicable because it has no OA intake.")
      return dcv_required
    end
    oa_flow_cfm = OpenStudio.convert(oa_flow_m3_per_s, 'm^3/s', 'cfm').get
    
    
    # Check for min OA without an economizer OR has economizer
    if oa_flow_cfm < min_oa_without_economizer_cfm && self.has_economizer == false
      # Message if doesn't pass OA limit
      if oa_flow_cfm < min_oa_without_economizer_cfm
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{template} #{climate_zone}:  #{self.name}: DCV is not required since the system min oa flow is #{oa_flow_cfm.round} cfm, less than the minimum of #{min_oa_without_economizer_cfm.round} cfm.")
      end
      # Message if doesn't have economizer
      if self.has_economizer == false
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{template} #{climate_zone}:  #{self.name}: DCV is not required since the system does not have an economizer.")
      end
      return dcv_required
    end

    # If has economizer, cfm limit is lower
    if oa_flow_cfm < min_oa_with_economizer_cfm && self.has_economizer
      OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{template} #{climate_zone}:  #{self.name}: DCV is not required since the system has an economizer, but the min oa flow is #{oa_flow_cfm.round} cfm, less than the minimum of #{min_oa_with_economizer_cfm.round} cfm for systems with an economizer.")
      return dcv_required
    end
   
    # If here, DCV is required
    dcv_required = true
    
    return dcv_required
   
  end    

  # Enable demand control ventilation (DCV) for this air loop.
  #
  # @return [Bool] Returns true if required, false if not.
  def enable_demand_control_ventilation()

    # Get the OA intake
    controller_oa = nil
    controller_mv = nil
    if air_loop.airLoopHVACOutdoorAirSystem.is_initialized
      oa_system = air_loop.airLoopHVACOutdoorAirSystem.get
      controller_oa = oa_system.getControllerOutdoorAir      
      controller_mv = controller_oa.controllerMechanicalVentilation
      if controller_mv.demandControlledVentilation == true
        air_loops_already_dcv << air_loop
        OpenStudio::logFree(OpenStudio::Info, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: DCV was already enabled.")
        return true
      end
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.standards.AirLoopHVAC', "For #{self.name}: Could not enable DCV since the system has no OA intake.")
      return false
    end
  
    # Change the min flow rate in the controller outdoor air
    controller_oa.setMinimumOutdoorAirFlowRate(0.0)
     
    # Enable DCV in the controller mechanical ventilation
    controller_mv.setDemandControlledVentilation(true)

    return true

  end
  
  # Determine if the system has an economizer
  #
  # @return [Bool] Returns true if required, false if not.  
  def has_economizer()
  
    # Get the OA system and OA controller
    oa_sys = self.airLoopHVACOutdoorAirSystem
    if oa_sys.is_initialized
      oa_sys = oa_sys.get
    else
      return false # No OA system
    end
    oa_control = oa_sys.getControllerOutdoorAir
    economizer_type = oa_control.getEconomizerControlType
    
    # Return false if no economizer is present
    if economizer_type == 'NoEconomizer'
      return false
    else
      return true
    end
    
  end
  
  # Determine if the system is a multizone VAV system
  #
  # @return [Bool] Returns true if required, false if not.  
  def is_multizone_vav_system()
    
    is_multizone_vav_system = false
    
    # Must serve more than 1 zone
    if self.thermalZones.size < 2
      return is_multizone_vav_system
    end
    
    # Must be a variable volume system
    has_vav_fan = false
    self.supplyComponents.each do |comp|
      if comp.to_FanVariableVolume.is_initialized
        has_vav_fan = true
      end
    end
    if has_vav_fan == false
      return is_multizone_vav_system
    end
    
    # If here, it's a multizone VAV system
    is_multizone_vav_system = true
    
    return is_multizone_vav_system

  end
  
end
