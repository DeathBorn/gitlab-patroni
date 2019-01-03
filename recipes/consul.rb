# Cookbook Name:: gitlab-patroni
# Recipe:: consul
# License:: MIT
#
# Copyright 2018, GitLab Inc.

check_interval = node['gitlab-patroni']['patroni']['consul']['check_interval']

service 'consul' do
  supports [:reload]
end

consul_definition 'patroni' do
  type 'services'
  parameters(
    [
      {
        id: 'patroni-master',
        name: 'patroni',
        tags: [
          'master'
        ],
        checks: [
          {
            http: "http://#{node['gitlab-patroni']['patroni']['config']['restapi']['listen']}/master",
            interval: check_interval
          }
        ].concat(node['gitlab-patroni']['patroni']['consul']['extra_checks'])
      },
      {
        id: 'patroni-replica',
        name: 'patroni',
        tags: [
          'replica'
        ],
        checks: [
          {
            http: "http://#{node['gitlab-patroni']['patroni']['config']['restapi']['listen']}/replica",
            interval: check_interval
          }
        ].concat(node['gitlab-patroni']['patroni']['consul']['extra_checks'])
      }
    ]
  )
  notifies :reload, 'service[consul]', :delayed
end
