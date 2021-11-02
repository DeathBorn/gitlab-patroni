if os.release.to_i < 18
  log %q(This test doesn't support Ubuntu versions older than 18.04.)
  return
end

control 'Pgwatch2 configuration' do
  title 'Verify correctness'

  describe service('pgwatch2') do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end

  describe file('/etc/systemd/system/pgwatch2.service') do
    its('content') { should match(%r{/usr/bin/pgwatch2-daemon -c /etc/pgwatch2/config/instances.yaml}) }
    its('content') { should match(%r{-m /etc/pgwatch2/metrics}) }
    its('content') { should match(%r{--ihost=127.0.0.1}) }
    its('content') { should match(%r{--idbname=pgwatch2}) }
    its('content') { should match(%r{--iuser=pgwatch2}) }
    its('content') { should match(%r{--ipassword=superuser-password}) }
    its('content') { should match(%r{--iretentiondays=30}) }
    its('content') { should match(%r{--iretentionname=pgwatch2_def_ret}) }
  end
end
