module GitlabPatroni
  class PostgresqlHelper
    attr_reader :node

    def initialize(node)
      @node = node
    end

    def postgresql_user
      node['gitlab-patroni']['user']
    end

    def postgresql_group
      node['gitlab-patroni']['user']
    end

    def postgresql_port
      node['gitlab-patroni']['postgresql']['parameters']['port']
    end

    def version
      node['gitlab-patroni']['postgresql']['version']
    end

    def previous_version
      node['gitlab-patroni']['postgresql']['previous_version']
    end
  end
end
