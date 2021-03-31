require 'csv'
require 'json'
require 'date'

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
    if row.has_key? "Budgeted"
      budget_entry(row)
    else
      register_entry(row)
    end
  end

  File.open("ynab_ledger.dat", "w") do |f|
    f.puts entries.compact.reverse.join("\n")
  end
end

def budget_entry(row)
  date = Date.parse(row["Month"])
  category = row["Category Group/Category"].sub(': ',':')

  <<END
#{date.strftime("%Y/%m/%d")} Budget
    budget:#{category}  #{row["Budgeted"]}
END
end

def register_entry(row)
  if row["Category"] == "To be Budgeted"
    source = "Income"
  elsif row["Payee"] == "Starting Balance"
    source = "Equity:Starting Balances"
  elsif row["Payee"] and row["Payee"].include?("Transfer :")
    account = row["Payee"].split(":").last.strip
    source = translate_account(account)
  else
    source = "Expenses:" + row["Category Group"] + ':' + row["Category"]
  end

  return if source == ""

  inflow = blank_if_zero(row["Inflow"])
  outflow = blank_if_zero(row["Outflow"])
  dest = translate_account(row["Account"])

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
