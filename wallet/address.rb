class Address
  attr_reader :address, :priv_key, :pub_key, :pub_key_hash160

  def initialize(*address_pack)
    @address, @priv_key, @pub_key, @pub_key_hash160 = address_pack[0], address_pack[1], address_pack[2], address_pack[3]
    @utxo = []
  end

  def get_utxo
    address = JSON.parse(Typhoeus.get("https://api.blockcypher.com/v1/btc/test3/addrs/#{@address}?unspentOnly=true").body)
    transactions = address["txrefs"]
    transactions.each do |tx|
      @utxo.push([tx['tx_hash'], tx["tx_output_n"], tx['value']/100000000.0])
    end
    @utxo
  end
end
