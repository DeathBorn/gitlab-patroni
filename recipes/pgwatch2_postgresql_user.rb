# Cookbook:: gitlab-patroni
# Recipe:: pgwatch2_postgresql_user
# License:: MIT
#
# Copyright:: 2021, GitLab Inc.
#
# Add PostgreSQL pgwatch2 user according to Postgres.ai documentation
# (https://gitlab.com/postgres-ai/pgwatch2/-/blob/afe5428397afd991f6d86d63ab756b97f1d5c7e1/docs/postgres.ai_edition_yaml_setup.md).

# Skip this recipe if Ubuntu is older than 18.04
if node['platform_version'].to_i < 18
  log %q(This recipe doesn't support Ubuntu versions older than 18.04.)
  return
end

if node['gitlab-patroni']['postgresql']['monitoring']['pgwatch2']['enable'] and `systemctl status patroni | grep RUNNING`
  default_role = node['gitlab-patroni']['user']
  password = node['gitlab-patroni']['patroni']['users']['superuser']['password']
  db_name = node['gitlab-patroni']['postgresql']['monitoring']['pgwatch2']['database_name']

  execute 'Create PostgreSQL database user for pgwatch2' do
    command %Q(gitlab-psql -d #{default_role} -c "CREATE ROLE pgwatch2 WITH LOGIN PASSWORD '#{password}';")
    sensitive true
    not_if %Q(gitlab-psql -d #{default_role} -c "SELECT 1 FROM pg_roles WHERE rolname='pgwatch2';" | grep -q 1)
  end

  bash 'Grant PostgreSQL permissions to pgwatch2 user' do
    code <<-EOH
      gitlab-psql -d #{default_role} -c "GRANT CONNECT ON DATABASE #{db_name} TO pgwatch2;"
      gitlab-psql -d #{default_role} -c "GRANT USAGE ON SCHEMA public TO pgwatch2;"
      gitlab-psql -d #{default_role} -c "GRANT pg_monitor TO pgwatch2;"
      gitlab-psql -d #{default_role} -c "GRANT EXECUTE ON FUNCTION pg_stat_file(text) to pgwatch2;"
      gitlab-psql -d #{default_role} -c "GRANT EXECUTE ON FUNCTION pg_ls_dir(text) TO pgwatch2;"
    EOH
  end

  execute 'Grant PostgreSQL pg_wait_sampling_reset_profile() permission to pgwatch2 user' do
    command %Q(gitlab-psql -d #{default_role} -c "GRANT EXECUTE ON FUNCTION pg_wait_sampling_reset_profile() TO pgwatch2;")
    only_if %Q(gitlab-psql -d #{default_role} -c  '\\df' | grep 'pg_wait_sampling_reset_profile()')
  end
end
