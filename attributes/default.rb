default['gitlab-patroni']['version'] = '1.5.0'
default['gitlab-patroni']['python_runtime_version'] = '3'
default['gitlab-patroni']['pip_version'] = '18.0'
default['gitlab-patroni']['data_directory'] = '/var/opt/gitlab/patroni'
default['gitlab-patroni']['install_directory'] = '/opt/patroni'
default['gitlab-patroni']['log_directory'] = '/var/log/gitlab/patroni'
default['gitlab-patroni']['postgresql_log_directory'] = '/var/log/gitlab/postgresql'
default['gitlab-patroni']['user'] = 'postgres'
default['gitlab-patroni']['group'] = 'postgres'
default['gitlab-patroni']['bind_interface'] = 'enp0s8'

superuser_username = default['gitlab-patroni']['superuser']['username'] = 'gitlab-superuser'
superuser_password = default['gitlab-patroni']['superuser']['password'] = 'in-vault'
replication_username = default['gitlab-patroni']['replication']['username'] = 'gitlab-replicator'
replication_password = default['gitlab-patroni']['replication']['password'] = 'in-vault'

default['gitlab-patroni']['secrets']['backend'] = 'gkms'
default['gitlab-patroni']['secrets']['path']['path'] = 'gitlab-gstg-secrets/gitlab-patroni'
default['gitlab-patroni']['secrets']['path']['item'] = 'gstg.enc'
default['gitlab-patroni']['secrets']['key']['ring'] = 'gitlab-secrets'
default['gitlab-patroni']['secrets']['key']['key'] = 'gstg'
default['gitlab-patroni']['secrets']['key']['location'] = 'global'

default['gitlab-patroni']['config']['scope'] = 'pg-ha-cluster'
default['gitlab-patroni']['config']['name'] = node.name
default['gitlab-patroni']['config']['restapi']['listen'] = '0.0.0.0:8009'
default['gitlab-patroni']['config']['consul']['host'] = '127.0.0.1:8500'

default['gitlab-patroni']['config']['bootstrap']['dcs']['ttl'] = 30
default['gitlab-patroni']['config']['bootstrap']['dcs']['loop_wait'] = 10
default['gitlab-patroni']['config']['bootstrap']['dcs']['retry_timeout'] = 10
default['gitlab-patroni']['config']['bootstrap']['dcs']['maximum_lag_on_failover'] = 1_048_576
default['gitlab-patroni']['config']['bootstrap']['dcs']['postgresql']['use_pg_rewind'] = true
default['gitlab-patroni']['config']['bootstrap']['dcs']['postgresql']['use_slots'] = true
default['gitlab-patroni']['config']['bootstrap']['dcs']['postgresql']['parameters']['wal_level'] = 'replica'
default['gitlab-patroni']['config']['bootstrap']['dcs']['postgresql']['parameters']['hot_standby'] = 'on'
default['gitlab-patroni']['config']['bootstrap']['dcs']['postgresql']['parameters']['wal_keep_segments'] = 8
default['gitlab-patroni']['config']['bootstrap']['dcs']['postgresql']['parameters']['max_wal_senders'] = 5
default['gitlab-patroni']['config']['bootstrap']['dcs']['postgresql']['parameters']['max_replication_slots'] = 5
default['gitlab-patroni']['config']['bootstrap']['dcs']['postgresql']['parameters']['checkpoint_timeout'] = 30
default['gitlab-patroni']['config']['bootstrap']['initdb'] = [{ 'encoding' => 'UTF8' }, { 'locale' => 'C.UTF-8' }]
default['gitlab-patroni']['config']['bootstrap']['users'][superuser_username]['password'] = superuser_password
default['gitlab-patroni']['config']['bootstrap']['users'][superuser_username]['options'] = %w[createrole createdb]
default['gitlab-patroni']['config']['bootstrap']['users'][replication_username]['password'] = replication_password
default['gitlab-patroni']['config']['bootstrap']['users'][replication_username]['options'] = ['replication']
default['gitlab-patroni']['config']['bootstrap']['pg_hba'] = [
  # 'host postgres gitlab-superuser 192.168.0.0/11 md5',
  # 'host all gitlab-superuser 192.168.0.0/11 md5',
  # 'host all gitlab-superuser 192.168.0.0/11 md5',
  # 'host all gitlab-superuser 127.0.0.1/32 md5',
  # 'host replication gitlab-replicator 127.0.0.1/32 md5',
  # 'host replication gitlab-replicator 192.168.0.0/11 md5',
]

default['gitlab-patroni']['config']['postgresql']['authentication']['superuser']['username'] = superuser_username
default['gitlab-patroni']['config']['postgresql']['authentication']['superuser']['password'] = superuser_password
default['gitlab-patroni']['config']['postgresql']['authentication']['replication']['username'] = replication_username
default['gitlab-patroni']['config']['postgresql']['authentication']['replication']['password'] = replication_password
default['gitlab-patroni']['config']['postgresql']['listen'] = '0.0.0.0:5433'
default['gitlab-patroni']['config']['postgresql']['data_dir'] = '/var/opt/gitlab/postgresql/data'
default['gitlab-patroni']['config']['postgresql']['config_dir'] = '/var/opt/gitlab/postgresql'
default['gitlab-patroni']['config']['postgresql']['bin_dir'] = '/usr/lib/postgresql/9.6/bin'
default['gitlab-patroni']['config']['postgresql']['parameters']['port'] = 5433
default['gitlab-patroni']['config']['postgresql']['parameters']['ssl'] = 'off'
default['gitlab-patroni']['config']['postgresql']['parameters']['log_destination'] = 'syslog'
