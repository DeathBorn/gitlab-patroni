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

    def assign_connect_addresses(node)
      address_detector     = GitlabPatroni::AddressDetector.new(node, node['gitlab-patroni']['patroni']['bind_interface'])
      postgres_listen_port = node['gitlab-patroni']['patroni']['config']['postgresql']['listen'].split(':').last
      patroni_listen_port  = node['gitlab-patroni']['patroni']['config']['restapi']['listen'].split(':').last

      node['gitlab-patroni']['patroni']['config']['restapi'] ||= {}
      node['gitlab-patroni']['patroni']['config']['restapi']['connect_address'] = "#{address_detector.ipaddress}:#{patroni_listen_port}"

      node['gitlab-patroni']['patroni']['config']['postgresql'] ||= {}
      node['gitlab-patroni']['patroni']['config']['postgresql']['connect_address'] = "#{address_detector.ipaddress}:#{postgres_listen_port}"
      node
    end

    def assign_postgresql_directories(node)
      node['gitlab-patroni']['patroni']['config']['postgresql'] ||= {}
      node['gitlab-patroni']['patroni']['config']['postgresql']['data_dir'] = node['gitlab-patroni']['postgresql']['data_directory']
      node['gitlab-patroni']['patroni']['config']['postgresql']['config_dir'] = node['gitlab-patroni']['postgresql']['config_directory']
      node['gitlab-patroni']['patroni']['config']['postgresql']['bin_dir'] = node['gitlab-patroni']['postgresql']['bin_directory']
      node
    end

    def assign_postgresql_parameters(node)
      node['gitlab-patroni']['patroni']['config']['postgresql'] ||= {}
      node['gitlab-patroni']['patroni']['config']['postgresql']['listen'] = node['gitlab-patroni']['postgresql']['listen_address']
      node['gitlab-patroni']['patroni']['config']['postgresql']['parameters'] = node['gitlab-patroni']['postgresql']['parameters']
      unless node['gitlab-patroni']['postgresql']['pg_ctl_timeout'].nil?
        node['gitlab-patroni']['patroni']['config']['postgresql']['pg_ctl_timeout'] = node['gitlab-patroni']['postgresql']['pg_ctl_timeout']
      end
      node
    end

    def assign_postgresql_users(node)
      node['gitlab-patroni']['patroni']['users'].each do |type, params|
        username = params['username']
        password = params['password']
        options  = params['options'] || []

        if %w(superuser replication rewind).include?(type)
          node.default['gitlab-patroni']['patroni']['config']['postgresql']['authentication'][type]['username'] = username
          node.default['gitlab-patroni']['patroni']['config']['postgresql']['authentication'][type]['password'] = password
        else
          username = type
        end

        node['gitlab-patroni']['patroni']['config']['bootstrap']['users'] ||= {}
        node['gitlab-patroni']['patroni']['config']['bootstrap']['users'][username] ||= {}
        node['gitlab-patroni']['patroni']['config']['bootstrap']['users'][username]['password'] = password
        node['gitlab-patroni']['patroni']['config']['bootstrap']['users'][username]['options'] = options

        # TODO (nnelson 2021-04-23): Is this deleted in main?
        node['gitlab-patroni']['patroni']['config']['postgresql'] ||= {}
        node['gitlab-patroni']['patroni']['config']['postgresql']['authentication'] ||= {}
        node['gitlab-patroni']['patroni']['config']['postgresql']['authentication'][type] ||= {}
        node['gitlab-patroni']['patroni']['config']['postgresql']['authentication'][type]['username'] = username
        node['gitlab-patroni']['patroni']['config']['postgresql']['authentication'][type]['password'] = password
      end
      node
    end
  end
end
