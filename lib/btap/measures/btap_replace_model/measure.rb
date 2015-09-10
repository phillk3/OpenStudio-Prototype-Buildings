
# see the URL below for information on how to write OpenStudio measures
# http://openstudio.nrel.gov/openstudio-measure-writing-guide
require 'fileutils'
require "date"

#some Library management. 
release_mode = false
folder = "#{File.dirname(__FILE__)}/../../../../lib/btap/lib/"
if release_mode == true
  #Copy BTAP files to measure from lib folder. Use this to create independant measure. 
  Dir.glob("#{folder}/**/*rb").each do |file|
    FileUtils.cp(file, File.dirname(__FILE__))
  end
  require "#{File.dirname(__FILE__)}/btap.rb"
else
  #For only when using git hub development environment.
  require "#{File.dirname(__FILE__)}/../../../../lib/btap/lib/btap.rb"
end


class ReplaceModel < BTAP::Measures::OSMeasures::BTAPModelUserScript

  # override name to return the name of your script
  def name
    return "Replaces OpenStudio Model with one loaded. "
  end

  # return a vector of arguments
  def arguments(model)
    #list of arguments as they will appear in the interface. They are available in the run command as
    @argument_array_of_arrays = [
      [    "variable_name",         "type",          "required",  "model_dependant", "display_name",                "default_value",                                     "min_value",  "max_value",  "string_choice_array",   "os_object_type"	    ],
      [    "alternativeModel",      "STRING",        true,        false,             "Alternative Model",           'FullServiceRestaurant.osm',                          nil,          nil,           nil,  	               nil					],
      [    "osm_directory",         "STRING",        true,        false,             "OSM Directory",               "../../lib/btap/resources/models/smart_archetypes",   nil,          nil,           nil,	                   nil					]     
    ]
    #set up arguments. 
    args = OpenStudio::Ruleset::OSArgumentVector.new
    self.argument_setter(args)
    return args
  end
  
  def measure_code(model,runner)
    #Arguments are that same as the variable names above with an @ before it: 
    #  @alternativeModel
    #  @osm_directory

    # report initial condition
    BTAP::runner_register("InitialCondition", "Model was #{model.building.get.name}.", runner)

    #set path to new model. 
    alternative_model_path = "#{@osm_directory.strip}/#{@alternativeModel.strip}"
    unless File.exist?(alternative_model_path.to_s) 
      BTAP::runner_register("Error","File does not exist: #{alternative_model_path.to_s}", runner) 
      return false
    end

    #try loading the file. 
    new_model = BTAP::FileIO::load_osm(alternative_model_path)

    # pull original weather file object over
    weather_file = new_model.getOptionalWeatherFile
    if not weather_file.empty?
      weather_file.get.remove
      BTAP::runner_register("Info", "Removed alternate model's weather file object.",runner)
    end
    original_weather_file = model.getOptionalWeatherFile
    if not original_weather_file.empty?
      original_weather_file.get.clone(new_model)
    end

    # pull original design days over
    new_model.getDesignDays.each { |designDay|
      designDay.remove
    }
    model.getDesignDays.each { |designDay|
      designDay.clone(new_model)
    }

    # swap underlying data in model with underlying data in new_model
    # remove existing objects from model
    handles = OpenStudio::UUIDVector.new
    model.objects.each do |obj|
      handles << obj.handle
    end
    model.removeObjects(handles)
    # add new file to empty model
    model.addObjects( new_model.toIdfFile.objects )
    BTAP::runner_register("Info",  "Model name is now #{model.building.get.name}.", runner)
    BTAP::runner_register("FinalCondition", "Model replaced with alternative #{alternative_model_path}. Weather file and design days retained from original.", runner)
    return true
  end
end

#this allows the measure to be used by the application
ReplaceModel.new.registerWithApplication
