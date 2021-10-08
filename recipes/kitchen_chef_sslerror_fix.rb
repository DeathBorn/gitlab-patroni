# Cookbook:: gitlab-patroni
# Recipe:: kitchen_chef_sslerror_fix
# License:: MIT
#
# Copyright:: 2021, GitLab Inc.
#
#  _________________________________
# /                                 \
# |     This recipe is intended     |
# |     for use with Test Kitchen.  |
# |     DO NOT use in Production.   |
# \_________________________________/
#                 !  !
#                 !  !
#                 L_ !
#                / _)!
#               / /__L
#         _____/ (____)
#                (____)
#         _____  (____)
#              \_(____)
#                 !  !
#                 !  !
#                 \__/

execute 'Download new certificate file from curl.se for Chef' do
  command 'rm -rf /opt/chef/embedded/ssl/cert.pem && curl https://curl.se/ca/cacert.pem -o /opt/chef/embedded/ssl/cert.pem'
  only_if { ENV['TEST_KITCHEN'] == '1' }
end
