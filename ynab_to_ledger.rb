require 'csv'
require 'json'

$config = JSON.parse(File.read('config.json'))

def get_type(payee)
  $config['account_types'].each do |type, accounts|
    if accounts.include?(payee)
      return type
    end
  end

  return "Assets"
end

def translate_account(payee)
  if $config['account_renames'].include?(payee)
    payee = $config['account_renames'][payee]
  end
  return get_type(payee) + ':' + payee
end

def main
  entries = CSV.read(ARGV.first, headers: true, encoding: "BOM|UTF-8").map do |row|
    ledger_entry(row)
  end

  File.open("ynab_ledger.dat", "w") do |f|
    f.puts entries.compact.reverse.join("\n")
  end
end

def ledger_entry(row)
  inflow = blank_if_zero(row["Inflow"])
  outflow = blank_if_zero(row["Outflow"])

  return if inflow == "" && outflow == ""

  month, day, year = row["Date"].split("/")

  if row["Category"] == "To be Budgeted"
    source = "Income"
  elsif row["Payee"] == "Starting Balance"
    source = "Equity:Starting Balances"
  elsif row["Payee"].include?("Transfer :")
    account = row["Payee"].split(":").last.strip
    source = translate_account(account)
  else
    source = "Expenses:" + row["Category Group"] + ':' + row["Category"]
  end

  return if source == ""

  suffix = row["Memo"] == "" ? "" : " ;" + row["Memo"]

  <<END
#{year}/#{month}/#{day} #{row["Payee"]}#{suffix}
    #{source}  #{outflow}
    #{translate_account(row["Account"])}  #{inflow}
END
end

def blank_if_zero(amount)
  amount =~ /\A\$?0.00\z/ ? "" : amount
end

main if __FILE__ == $0
