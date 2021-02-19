Facter.add(:galera_is_bootstrap) do
  setcode do
    begin
      Facter::Core::Execution.execute('/usr/bin/systemctl status mysql@bootstrap | grep -q running')
    rescue Facter::Core::Execution::ExecutionFailure
      false
    else
      true
    end
  end
end