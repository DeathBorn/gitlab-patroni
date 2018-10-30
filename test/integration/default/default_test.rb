# InSpec tests for recipe gitlab-patroni::default

control 'general-checks' do
  impact 1.0
  title 'General tests for gitlab-patroni cookbook'
  desc '
    This control ensures that:
      * there is no duplicates in /etc/group'

  describe etc_group do
    its('gids') { should_not contain_duplicates }
  end
end
