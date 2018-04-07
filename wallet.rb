require 'bitcoin'
require 'json'
require 'typhoeus'
require 'pp'
require 'slop'
require './wallet/address'
include Bitcoin::Builder

# use testnet so you don't accidentally blow your whole money!
Bitcoin.network = :testnet3

# Slop
opts = Slop.parse(help: true) do |o|
    o.string '-t', '--type', 'type of operations'
    o.bool '--send'
    o.bool '--show'
end

# create and save address
if opts[:type] == "generate"
  address = Bitcoin::generate_address
  address.each do |item|
    puts item
  end
  File.open('address.txt', 'a') do |file|
      file.puts address.join(',')
  end
end
# order => address, private key(hex), publick key(hex), hash160(pubkey)

recipient = "mn4YPH7koKLC91LkuVriqtfDhpnAksognW"

# get address from address.txt
address_pack = []
File.open('address.txt', 'r') do |file|
    file.each_line do |line|
        line.chomp!
        address_pack.push(line.split(','))
    end
end

sender = Address.new(*address_pack)

for pack in address_pack
    if pack[0] == sender then
        priv_key, pub_key, pub_key_hash160 = pack[1], pack[2], pack[3]
        break
    end
end

if opts[:send]
    puts "Chose address:"
    n = 0
    address_pack.each do |list|
        puts "#{n.to_s}: #{list[0]}"
        n += 1
    end
    puts "Number:"
    sender = STDIN.gets.to_i
    priv_key, pub_key, pub_key_hash160 = address_pack[sender][1], address_pack[sender][2], address_pack[sender][3]

    key = Bitcoin::Key.new(priv_key, pub_key)

    # create transaction
    # get unspent tx outputs
    prev_tx = JSON.parse(Typhoeus.get("https://api.blockcypher.com/v1/btc/test3/addrs/#{sender}?unspentOnly=true").body)
    prev_hash = prev_tx["txrefs"][0]["tx_hash"]

    # hex tx to binary tx
    prev_tx_hex = JSON.parse(Typhoeus.get("https://api.blockcypher.com/v1/btc/test3/txs/#{prev_hash}?includeHex=true").body)["hex"]
    prev_tx_bin = Bitcoin::P::Tx.new([prev_tx_hex].pack('H*'))
    prev_out_index = prev_tx["txrefs"][0]["tx_output_n"]
    balance = JSON.parse(Typhoeus.get("https://api.blockcypher.com/v1/btc/test3/addrs/#{sender}/balance").body)["balance"]

    send_amount = 1000000 # satoshis = 0.01 BTC
    fee_amount = 100000
    change = balance - send_amount - fee_amount

    new_tx = build_tx do |t|
      t.input do |i|
        i.prev_out prev_tx_bin, prev_out_index
        i.signature_key key
      end

      t.output do |o|
        o.value send_amount
        o.script {|s| s.recipient recipient }
      end

      # change
      t.output do |o|
       o.value change
       o.script {|s| s.recipient key.addr }
      end
    end
end

# broadcast
body = {tx: "#{new_tx.to_payload.unpack("H*")[0]}"}
response = Typhoeus.post("https://api.blockcypher.com/v1/btc/test3/txs/push", body: body.to_json)

# debug
pp "prev_tx: #{prev_tx}"
pp "prev_hash: #{prev_hash}"
puts "hex transaction is\n#{new_tx.to_payload.unpack("H*")[0]}"
