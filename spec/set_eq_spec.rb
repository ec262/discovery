require 'spec_helper'

describe 'Set Equality method' do
  a = [1, 2, 3]
  b = [1, 2, 3]
  c = [1, 2, 4]
  d = [1, 2]
  e = [1, 2, 3, 4]
  f = [1, 2, 2, 3]
  
  it 'works on equal arrays' do
    a.set_eq(b).should be_true
  end
  
  it 'fails on different arrays' do
    [c, d, e, f].each do |s|
      a.set_eq(s).should be_false
    end
  end
  
end
