module GitlabPatroni
  module AttributesHelper
    extend self

    def populate_missing_values(patroni_conf)
      patroni_conf = assign_postgresql_directories(patroni_conf)
      patroni_conf = assign_postgresql_parameters(patroni_conf)
      patroni_conf = assign_postgresql_users(patroni_conf)
      patroni_conf = assign_connect_addresses(patroni_conf)
      patroni_conf
    end

    private

    def assign_connect_addresses(patroni_conf)
      address_detector     = GitlabPatroni::AddressDetector.new(patroni_conf, patroni_conf['gitlab-patroni']['patroni']['bind_interface'])
      postgres_listen_port = patroni_conf['gitlab-patroni']['patroni']['config']['postgresql']['listen'].split(':').last
      patroni_listen_port  = patroni_conf['gitlab-patroni']['patroni']['config']['restapi']['listen'].split(':').last

      patroni_conf['gitlab-patroni']['patroni']['config']['restapi'] ||= {}
      patroni_conf['gitlab-patroni']['patroni']['config']['restapi']['connect_address'] = "#{address_detector.ipaddress}:#{patroni_listen_port}"

      patroni_conf['gitlab-patroni']['patroni']['config']['postgresql'] ||= {}
      patroni_conf['gitlab-patroni']['patroni']['config']['postgresql']['connect_address'] = "#{address_detector.ipaddress}:#{postgres_listen_port}"
      patroni_conf
    end

    def assign_postgresql_directories(patroni_conf)
      patroni_conf['gitlab-patroni']['patroni']['config']['postgresql'] ||= {}
      patroni_conf['gitlab-patroni']['patroni']['config']['postgresql']['data_dir'] = patroni_conf['gitlab-patroni']['postgresql']['data_directory']
      patroni_conf['gitlab-patroni']['patroni']['config']['postgresql']['config_dir'] = patroni_conf['gitlab-patroni']['postgresql']['config_directory']
      patroni_conf['gitlab-patroni']['patroni']['config']['postgresql']['bin_dir'] = patroni_conf['gitlab-patroni']['postgresql']['bin_directory']
      patroni_conf
    end

    def assign_postgresql_parameters(patroni_conf)
      patroni_conf['gitlab-patroni']['patroni']['config']['postgresql'] ||= {}
      patroni_conf['gitlab-patroni']['patroni']['config']['postgresql']['listen'] = patroni_conf['gitlab-patroni']['postgresql']['listen_address']
      patroni_conf['gitlab-patroni']['patroni']['config']['postgresql']['parameters'] = patroni_conf['gitlab-patroni']['postgresql']['parameters']
      unless patroni_conf['gitlab-patroni']['postgresql']['pg_ctl_timeout'].nil?
        patroni_conf['gitlab-patroni']['patroni']['config']['postgresql']['pg_ctl_timeout'] = patroni_conf['gitlab-patroni']['postgresql']['pg_ctl_timeout']
      end
      patroni_conf
    end

    def assign_postgresql_users(patroni_conf)
      patroni_conf['gitlab-patroni']['patroni']['users'].each do |type, params|
        username = params['username']
        password = params['password']
        options  = params['options'] || []

        if %w(superuser replication rewind).include?(type)
          patroni_conf['gitlab-patroni']['patroni']['config']['postgresql'] ||= {}
          patroni_conf['gitlab-patroni']['patroni']['config']['postgresql']['authentication'] ||= {}
          patroni_conf['gitlab-patroni']['patroni']['config']['postgresql']['authentication'][type] ||= {}
          patroni_conf['gitlab-patroni']['patroni']['config']['postgresql']['authentication'][type]['username'] = username
          patroni_conf['gitlab-patroni']['patroni']['config']['postgresql']['authentication'][type]['password'] = password
        else
          username = type
        end

        patroni_conf['gitlab-patroni']['patroni']['config']['bootstrap']['users'] ||= {}
        patroni_conf['gitlab-patroni']['patroni']['config']['bootstrap']['users'][username] ||= {}
        patroni_conf['gitlab-patroni']['patroni']['config']['bootstrap']['users'][username]['password'] = password
        patroni_conf['gitlab-patroni']['patroni']['config']['bootstrap']['users'][username]['options'] = options
      end
      patroni_conf
    end
  end
end
