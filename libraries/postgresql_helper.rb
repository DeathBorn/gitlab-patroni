module GitlabPatroni
  class PostgresqlHelper
    attr_reader :node

    def initialize(node)
      @node = node
    end

    def postgresql_db_name
      node['gitlab-patroni']['db_name']
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

    def dir_exist_not_postgres_owned?(dir)
      File.exist?(dir) && (Etc.getpwuid(::File.stat(dir).uid).name != postgresql_user)
    end
  end
end
