class Address
  attr_reader :address, :priv_key, :pub_key, :pub_key_hash160

  def initialize(*address_pack)
    @address, @priv_key, @pub_key, @pub_key_hash160 = address_pack[0], address_pack[1], address_pack[2], address_pack[3]
  end
end
