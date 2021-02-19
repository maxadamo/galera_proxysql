Facter.add(:galera_is_bootstrap) do
  setcode do
    begin
      Facter::Core::Execution.execute('ps -ef | grep mysql@bootstrap')
    rescue Facter::Core::Execution::ExecutionFailure
      false
    else
      true
    end
  end
end