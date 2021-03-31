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
  if row["Category"] == "To be Budgeted"
    category = "Income"
  elsif row["Payee"] == "Starting Balance"
    category = "Equity:Starting Balances"
  elsif row["Payee"].include?("Transfer :")
    account = row["Payee"].split(":").last.strip
    category = translate_account(account)
  else
    category = "Expenses:" + row["Category Group"] + ':' + row["Category"]
  end

  return if category == ""

  if row.has_key? "Budgeted"
    inflow = row["Budgeted"]
    dest = category
  else
    inflow = blank_if_zero(row["Inflow"])
    outflow = blank_if_zero(row["Outflow"])
    dest = translate_account(row["Account"])
    source = category
  end

  return if inflow == "" && outflow == ""

  month, day, year = row["Date"].split("/")

  suffix = row["Memo"] == "" ? "" : " ;" + row["Memo"]

  <<END
#{year}/#{month}/#{day} #{row["Payee"]}#{suffix}
    #{source}  #{outflow}
    #{dest}  #{inflow}
END
end

def blank_if_zero(amount)
  amount =~ /\A\$?0.00\z/ ? "" : amount
end

main if __FILE__ == $0
