control 'PostgreSQL extension pg_stat_kcache' do
  title 'Check if extension is present'

  # NOTE: Update the postgresql version when the default changes
  describe package('postgresql-12-pg-stat-kcache') do
    it { should be_installed }
  end
end
