/// A currency the rider can pick; [symbol] is what shows before amounts.
class Currency {
  const Currency(this.code, this.name, this.symbol);

  final String code;
  final String name;
  final String symbol;
}

const currencies = <Currency>[
  Currency('USD', 'US dollar', r'$'),
  Currency('EUR', 'Euro', '€'),
  Currency('GBP', 'British pound', '£'),
  Currency('INR', 'Indian rupee', '₹'),
  Currency('BDT', 'Bangladeshi taka', '৳'),
  Currency('PKR', 'Pakistani rupee', 'Rs'),
  Currency('LKR', 'Sri Lankan rupee', 'Rs'),
  Currency('NPR', 'Nepalese rupee', 'Rs'),
  Currency('AED', 'UAE dirham', 'AED'),
  Currency('SAR', 'Saudi riyal', 'SAR'),
  Currency('QAR', 'Qatari riyal', 'QAR'),
  Currency('KWD', 'Kuwaiti dinar', 'KWD'),
  Currency('TRY', 'Turkish lira', '₺'),
  Currency('JPY', 'Japanese yen', '¥'),
  Currency('CNY', 'Chinese yuan', 'CN¥'),
  Currency('KRW', 'South Korean won', '₩'),
  Currency('IDR', 'Indonesian rupiah', 'Rp'),
  Currency('MYR', 'Malaysian ringgit', 'RM'),
  Currency('SGD', 'Singapore dollar', r'S$'),
  Currency('THB', 'Thai baht', '฿'),
  Currency('VND', 'Vietnamese dong', '₫'),
  Currency('PHP', 'Philippine peso', '₱'),
  Currency('AUD', 'Australian dollar', r'A$'),
  Currency('NZD', 'New Zealand dollar', r'NZ$'),
  Currency('CAD', 'Canadian dollar', r'C$'),
  Currency('MXN', 'Mexican peso', r'MX$'),
  Currency('BRL', 'Brazilian real', r'R$'),
  Currency('ARS', 'Argentine peso', r'AR$'),
  Currency('CLP', 'Chilean peso', r'CL$'),
  Currency('COP', 'Colombian peso', r'CO$'),
  Currency('CHF', 'Swiss franc', 'CHF'),
  Currency('SEK', 'Swedish krona', 'kr'),
  Currency('NOK', 'Norwegian krone', 'kr'),
  Currency('DKK', 'Danish krone', 'kr'),
  Currency('PLN', 'Polish złoty', 'zł'),
  Currency('CZK', 'Czech koruna', 'Kč'),
  Currency('HUF', 'Hungarian forint', 'Ft'),
  Currency('RON', 'Romanian leu', 'lei'),
  Currency('UAH', 'Ukrainian hryvnia', '₴'),
  Currency('RUB', 'Russian ruble', '₽'),
  Currency('ILS', 'Israeli shekel', '₪'),
  Currency('EGP', 'Egyptian pound', 'E£'),
  Currency('ZAR', 'South African rand', 'R'),
  Currency('NGN', 'Nigerian naira', '₦'),
  Currency('KES', 'Kenyan shilling', 'KSh'),
];

const defaultCurrency = Currency('USD', 'US dollar', r'$');

Currency? currencyByCode(String? code) {
  for (final c in currencies) {
    if (c.code == code) return c;
  }
  return null;
}
