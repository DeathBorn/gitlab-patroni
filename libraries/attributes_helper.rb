module GitlabPatroni
  module AttributesHelper
    extend self

    def populate_missing_values(node)
      assign_postgresql_directories(node)
      assign_postgresql_parameters(node)
      assign_postgresql_users(node)
      assign_connect_addresses(node)
    end

    private

    def assign_connect_addresses(node)
      address_detector     = GitlabPatroni::AddressDetector.new(node, node['gitlab-patroni']['patroni']['bind_interface'])
      postgres_listen_port = node['gitlab-patroni']['patroni']['config']['postgresql']['listen'].split(':').last
      patroni_listen_port  = node['gitlab-patroni']['patroni']['config']['restapi']['listen'].split(':').last

      node.default['gitlab-patroni']['patroni']['config']['restapi']['connect_address']    = "#{address_detector.ipaddress}:#{patroni_listen_port}"
      node.default['gitlab-patroni']['patroni']['config']['postgresql']['connect_address'] = "#{address_detector.ipaddress}:#{postgres_listen_port}"
    end

    def assign_postgresql_directories(node)
      node.default['gitlab-patroni']['patroni']['config']['postgresql']['data_dir']   = node['gitlab-patroni']['postgresql']['data_directory']
      node.default['gitlab-patroni']['patroni']['config']['postgresql']['config_dir'] = node['gitlab-patroni']['postgresql']['config_directory']
      node.default['gitlab-patroni']['patroni']['config']['postgresql']['bin_dir'] = node['gitlab-patroni']['postgresql']['bin_directory']
    end

    def assign_postgresql_parameters(node)
      node.default['gitlab-patroni']['patroni']['config']['postgresql']['listen'] = node['gitlab-patroni']['postgresql']['listen_address']
      unless node['gitlab-patroni']['postgresql']['pg_ctl_timeout'].nil?
        node.default['gitlab-patroni']['patroni']['config']['postgresql']['pg_ctl_timeout'] = node['gitlab-patroni']['postgresql']['pg_ctl_timeout']
      end
      node.default['gitlab-patroni']['patroni']['config']['postgresql']['parameters'] = node['gitlab-patroni']['postgresql']['parameters']
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

        node.default['gitlab-patroni']['patroni']['config']['bootstrap']['users'][username]['password'] = password
        node.default['gitlab-patroni']['patroni']['config']['bootstrap']['users'][username]['options'] = options
      end
    end
  end
end
