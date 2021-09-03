control 'PostgreSQL extension pg_wait_sampling' do
  title 'Check if extension is present'

  # NOTE: Update the postgresql version when the default changes
  describe package('postgresql-11-pg-wait-sampling') do
    it { should be_installed }
  end
end
