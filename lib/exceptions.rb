# Abstract base class for application exceptions
class DiscoveryServiceException < StandardError
  def code; end
  def response; end
end

class InsufficientCredits < DiscoveryServiceException
  def initialize(available_credits, needed_credits)
    @available_credits = available_credits
    @needed_credits = needed_credits
  end
  
  def code; 406 end
  
  def response
    { :error => "Insufficient credits",
      :available_credits => @available_credits,
      :needed_credits => @needed_credits
    }
  end
end

class UnknownTask < DiscoveryServiceException
  def code; 404 end
  
  def response
    { :error => "Unknown task" }
  end
end

class UnknownClient < DiscoveryServiceException
  def code; 404 end
  
  def response
    { :error => "Unknown client" }
  end
end