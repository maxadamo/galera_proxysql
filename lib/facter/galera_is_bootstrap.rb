Facter.add(:galera_is_bootstrap) do
  setcode do
    begin
      Facter::Core::Execution.execute('/usr/bin/systemctl status mysql@bootstrap')
    rescue Facter::Core::Execution::ExecutionFailure
      service_status = 'DOWN'
    else
      service_status = 'UP'
    end
    if service_status == 'DOWN'
      true
    else
      false
    end
  end
end