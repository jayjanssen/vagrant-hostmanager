require 'vagrant-hostmanager/hosts_file/updater'
require 'vagrant-hostmanager/util'

module VagrantPlugins
  module HostManager
    module Action
      class UpdateAll

        def initialize(app, env)
          @app = app
          @machine = env[:machine]
          @global_env = @machine.env
          @provider = @machine.provider_name
          @config = Util.get_config(@global_env)
          @updater = HostsFile::Updater.new(@global_env, @provider)
          @logger = Log4r::Logger.new('vagrant::hostmanager::update_all')
        end

        def call(env)
          # skip if machine is not active on destroy action
          # return @app.call(env) if !@machine.id && env[:machine_action] == :destroy
          return @app.call(env) if !@updater.ip_cache.get_host( @machine.name ) && env[:machine_action] == :destroy
        
          # Return if the destroy was not confirmed
          return @app.call(env) if env[:machine_action] == :destroy and env[:force_confirm_destroy_result] == false and env[:force_confirm_destroy] == false 
            
          # Purge the machine from the ip cache
          if env[:machine_action] == :destroy
            @updater.ip_cache.delete_host( @machine.name )
          end

          # check config to see if the hosts file should be update automatically
          return @app.call(env) unless @config.hostmanager.enabled?
          @logger.info 'Updating /etc/hosts file automatically'

          @app.call(env)

          # update /etc/hosts file on active machines
          env[:ui].info I18n.t('vagrant_hostmanager.action.update_guests')
          @global_env.active_machines.each do |name, p|
            if p == @provider
              machine = @global_env.machine(name, p)
              @updater.update_guest(machine)
            end
          end

          # update /etc/hosts files on host if enabled
          if @machine.config.hostmanager.manage_host?
            env[:ui].info I18n.t('vagrant_hostmanager.action.update_host')
            @updater.update_host
          end
        end
      end
    end
  end
end
