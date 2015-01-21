
# open the class to add methods to return sizing values
class OpenStudio::Model::FanVariableVolume

  # Sets the fan motor efficiency based on the standard
  def setStandardEfficiency(template, hvac_standards)
    
    motors = hvac_standards['motors']
    
    # Get the max flow rate from the fan.
    # This expects that the fan is hard sized.
    maximum_flow_rate_m3_per_s = self.maximumFlowRate
    if maximum_flow_rate_m3_per_s.is_initialized
      maximum_flow_rate_m3_per_s = maximum_flow_rate_m3_per_s.get
    else
      OpenStudio::logFree(OpenStudio::Warn, 'openstudio.hvac_standards.FanVariableVolume', "For #{self.name} max flow rate is not hard sized, cannot apply efficiency standard.")
      return false
    end
    
    # Convert max flow rate to cfm
    maximum_flow_rate_cfm = OpenStudio.convert(maximum_flow_rate_m3_per_s, 'm^3/s', 'cfm').get
    
    # Get the pressure rise from the fan
    pressure_rise_pa = self.pressureRise
    pressure_rise_in_h2o = OpenStudio.convert(pressure_rise_pa, 'Pa','inH_{2}O').get
    
    # Assume that the fan efficiency is 65% based on
    #TODO need reference
    fan_eff = 0.65
    
    # Calculate the Brake Horsepower
    brake_hp = (pressure_rise_in_h2o * maximum_flow_rate_cfm)/(fan_eff * 6356) 
    allowed_hp = brake_hp * 1.1 # Per PNNL document #TODO add reference
    
    # Find the motor that meets these size criteria
    search_criteria = {
    'template' => template,
    'number_of_poles' => 4.0,
    'type' => 'Open Drip-Proof',
    }
    
    motor_properties = find_object(motors, search_criteria, allowed_hp)
  
    # Get the nominal motor efficiency
    motor_eff = motor_properties['nominal_full_load_efficiency']
  
    # Calculate the total fan efficiency
    total_fan_eff = fan_eff * motor_eff
    
    # Set the total fan efficiency and the motor efficiency
    self.setFanEfficiency(total_fan_eff)
    self.setMotorEfficiency(motor_eff)
    
    OpenStudio::logFree(OpenStudio::Info, 'openstudio.model.FanVariableVolume', "For #{template}: #{self.name}: allowed_hp = #{allowed_hp.round}HP; motor eff = #{motor_eff*100}%; total fan eff = #{total_fan_eff*100}%")
    
    return true
    
  end
  
end
