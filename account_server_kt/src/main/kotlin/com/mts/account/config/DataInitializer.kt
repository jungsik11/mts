package com.mts.account.config

import com.mts.account.model.Account
import com.mts.account.model.User
import com.mts.account.model.Asset
import com.mts.account.repository.AccountRepository
import com.mts.account.repository.UserRepository
import com.mts.account.repository.AssetRepository
import org.springframework.boot.CommandLineRunner
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.security.crypto.password.PasswordEncoder

@Configuration
class DataInitializer {

    @Bean
    fun initData(userRepository: UserRepository, accountRepository: AccountRepository, assetRepository: AssetRepository, passwordEncoder: PasswordEncoder): CommandLineRunner {
        return CommandLineRunner {
            // 1. Account Migration (Keep existing logic)
            val allAccounts = accountRepository.findAll()
            val accountsToMigrate = allAccounts.filter { !it.accountNumber.matches(Regex("\\d{8}-\\d{2}")) }
            
            if (accountsToMigrate.isNotEmpty()) {
                val existingNumbers = allAccounts.map { it.accountNumber }.toMutableSet()
                println("Migrating ${accountsToMigrate.size} accounts...")
                accountsToMigrate.forEach { acc ->
                    var newAccNum: String
                    do {
                        val base = (10000000..99999999).random().toString()
                        val code = when (acc.accountType.uppercase()) {
                            "CMA" -> "21"
                            "PENSION", "연금", "연금 계좌" -> "22"
                            else -> "01"
                        }
                        newAccNum = "$base-$code"
                    } while (existingNumbers.contains(newAccNum))
                    
                    acc.accountNumber = newAccNum
                    accountRepository.save(acc)
                    existingNumbers.add(newAccNum)
                }
                println("Migration complete.")
            }

            // 2. Create Admin if not exists
            if (userRepository.findByUsername("admin") == null) {
                val admin = User(username = "admin", passwordHash = passwordEncoder.encode("admin123"), email = "admin@example.com", name = "System Administrator")
                val savedAdmin = userRepository.save(admin)
                accountRepository.save(Account(userId = savedAdmin.id, accountNumber = "10000000-01", accountType = "ADMIN", balance = 10000000.0, isPrimary = true))
                println("Admin created")
            }
            
            // 3. Define 1000 Deterministic Tickers (Matching price_generator.py)
            val baseTickers = listOf("005930", "000660", "035420", "035720", "005380", "005490", "000270", "068270", "006400", "051910")
            val krMockTickers = (100..999).map { "K$it" }
            
            // Real-world US Tickers
            val usTickersPart0 = listOf("SNEX", "GIS", "HR", "MSA", "PG", "HPQ", "ABT", "MOH", "ZM", "BR", "DLR", "CFR", "FITBI", "TRMB", "FHN", "WES", "ONBPP", "C", "WTS", "ATO", "MKSI", "TPGXL", "MTSI", "RL", "FNF", "INCY", "CSGP", "DTM", "NTRA", "MASI", "RPM", "CELC", "SIRI", "GPN", "THG", "P", "TME", "AGX", "SNDK", "ALB", "NEE", "MSCI", "RIOT", "AON", "ULS", "LLYVA", "RCL", "MDLZ", "AHR", "CEG", "CHD", "LAD", "INTC", "MSI", "TSN", "MAS", "OKLO", "ORI", "D", "ONTO", "VLYPO", "VMC", "MDGL", "ES", "BIIB", "MYRG", "RJF", "XOM", "PCAR", "GOOGL", "PM", "JBL", "LNT", "HBANM", "TTMI", "PCOR", "HLI", "VAL", "SCCO", "BRKR", "SNAP", "DLTR", "GM", "TKR", "SRE", "IT", "SATA", "WEC", "NBIX", "CAT", "CGNX", "SOMN", "AFRM", "AAOI", "PLTR", "LKQ", "FOX", "EVR", "PRU", "AMG")
            val usTickersPart1 = listOf("TXRH", "ALNY", "AROC", "AN", "VICR", "MORN", "SYRE", "SWKS", "HSY", "WPC", "VIRT", "ETR", "PFG", "NFLX", "STRL", "MTCH", "VG", "PL", "XEL", "COHR", "INVH", "MKL", "BBY", "KEYS", "RRX", "HBAN", "CRUS", "RVTY", "POOL", "THC", "BOKF", "W", "VOYA", "AGNCM", "HAS", "R", "CTAS", "T", "DOV", "SARO", "OSCR", "VFC", "CBC", "CRCL", "SPXC", "FSLR", "WSM", "HUBB", "STLD", "AMH", "SFD", "PB", "SOFI", "TPG", "BMNR", "EFX", "TRV", "FITB", "HRL", "WTFC", "SMMT", "RKLB", "CDW", "VEEV", "CLF", "DT", "FISV", "NE", "UTHR", "LOW", "MIRM", "SOJE", "NXT", "HPE", "SWK", "CNM", "BLD", "CMCSA", "DKNG", "CHDN", "VICI", "MTZ", "ELV", "COP", "AXON", "PKG", "GBCI", "REXR", "AVT", "EIX", "ET", "ABBV", "AGNCO", "ITT", "DKS", "SANM", "COKE", "QCOM", "OXY", "FTAI")
            val usTickersPart2 = listOf("UGI", "NSC", "AMT", "RF", "CE", "MPWR", "CGON", "CRM", "BAX", "STRC", "IMVT", "EWBC", "LLYVK", "NDAQ", "PEN", "KRMN", "APOS", "AA", "QBTS", "ROKU", "HCA", "IFF", "USB", "UNH", "MIDD", "FCX", "HII", "DIS", "ATR", "OKTA", "AMZN", "AUGO", "VIAV", "ILMN", "DPZ", "RSG", "GME", "GGG", "OHI", "V", "ERIE", "FAF", "ESS", "SLMBP", "CSX", "SPG", "MSFT", "CPAY", "JNJ", "FANG", "GLW", "NTAP", "STRF", "AEE", "MSTR", "WLK", "IDXX", "NYT", "PRMB", "MDLN", "ZION", "ALLE", "ZG", "EVRG", "GEHC", "ACI", "AJG", "QXO", "APGE", "ARMK", "AIG", "GWW", "MU", "FCNCA", "EBAY", "IBKR", "PTC", "FIX", "IRM", "BRO", "CQP", "GDDY", "KMB", "VLTO", "CAH", "CHRD", "ED", "FWONA", "TRNO", "JKHY", "KIM", "AEP", "SUI", "CRBG", "CMS", "PRS", "BRK-B", "URI", "NI", "YUMC")
            val usTickersPart3 = listOf("AMAT", "VLYPP", "STZ", "KDP", "FITBP", "KRYS", "KHC", "AM", "WRB", "DE", "H", "REG", "SSNC", "WTRG", "TXN", "CWAN", "AIZ", "FROG", "EPD", "TW", "LH", "BIO", "PRI", "MNST", "TRU", "A", "EHC", "DGX", "LTH", "RBLX", "GD", "FTNT", "DDS", "ZS", "CHYM", "BYD", "DG", "DY", "STT", "KVUE", "BG", "REGN", "MLM", "VIK", "IVZ", "TOL", "CNC", "TMO", "BTSG", "ECG", "TXNM", "PSKY", "CR", "LNG", "HEI", "HON", "SFM", "GAP", "TMUS", "MEDP", "INGR", "JBHT", "VRSN", "NOW", "RS", "FLS", "TECH", "DRI", "RYTM", "MP", "PPLC", "NOV", "MPLX", "FLY", "HD", "WFRD", "PLXS", "MAR", "MA", "FR", "CGABL", "PWR", "MDT", "WWD", "ACA", "ADBE", "XYL", "WFC", "HLT", "ASTS", "CPRT", "GJS", "YUM", "ABNB", "KLAC", "LII", "CRWD", "PPL", "CLH", "AXTA")
            val usTickersPart4 = listOf("MXL", "TDY", "EQR", "NUE", "MHK", "KMI", "SYM", "TOST", "TTEK", "SMCI", "SBAC", "PH", "IDA", "EMR", "DD", "ADM", "TRGP", "NOC", "SOLS", "ONBPO", "PFH", "EXPE", "BROS", "AVY", "IBRX", "TLN", "FTV", "GTLS", "KKRS", "NIO", "FTS", "F", "MOS", "GH", "ESI", "GNRC", "AMP", "LITE", "CORZ", "BA", "CTSH", "TWLO", "WMG", "OC", "SNX", "DOCN", "CMSD", "PAYC", "DASH", "FRVO", "CPNG", "TPL", "HXL", "DOW", "VLYPN", "BDX", "SEIC", "ODFL", "BRX", "JBTM", "NLY", "CSCO", "PAA", "LMT", "HUM", "CHTR", "NKE", "FIG", "HBANZ", "CRDO", "RYN", "MMM", "MDB", "TSCO", "NET", "KTOS", "CAVA", "GKOS", "CIFR", "EMP", "CCL", "PLD", "PPC", "WST", "BJ", "JPM", "LUV", "EAT", "YOU", "ATI", "ARW", "CG", "ARES", "UAL", "ECL", "HST", "FICO", "USFD", "MS", "FIS")
            val usTickersPart5 = listOf("CMSA", "AXSM", "MKC", "BKNG", "MTB", "LLY", "ARWR", "SNPS", "CRS", "SYF", "PRH", "LVS", "AGNCP", "AQNB", "TFC", "MCHP", "APG", "GEV", "AVB", "EQIX", "RYAN", "MSGS", "VSNT", "FWONK", "EXR", "WBD", "IBP", "AKAM", "PSX", "LEA", "JXN", "UDR", "OGE", "ELAN", "PGR", "PTGX", "PNW", "IR", "RBRK", "IDCC", "CASY", "MRK", "MCK", "SITM", "APO", "BEPC", "GE", "CI", "AR", "LNTH", "GPC", "ULTA", "STE", "CUBE", "CMG", "ICE", "DTE", "TTC", "RTX", "SATS", "NTNX", "PJT", "IBM", "ORA", "ONB", "DBX", "JLL", "OKE", "EL", "COIN", "CCI", "DHI", "STWD", "ALGM", "CME", "DUK", "SWX", "PNC", "VRTX", "TRI", "FNB", "META", "NNN", "HBANP", "BALL", "FRT", "IONS", "HIG", "STRK", "MTDR", "TYL", "AGNCL", "GSAT", "CET", "PR", "FIVE", "MLI", "APH", "DHR", "CSL")
            val usTickersPart6 = listOf("KEX", "BRK-A", "MRVL", "NEU", "VTRS", "Q", "WM", "OSK", "FDS", "DAL", "DVA", "LHX", "EME", "MANH", "AUR", "GEN", "ARE", "TGTX", "ISRG", "GS", "SMTC", "ARCC", "LUNR", "RGA", "WMB", "PPG", "EA", "AES", "APA", "BXP", "TDG", "UBER", "BEN", "CELH", "Z", "CART", "LSCC", "CHRW", "AOS", "XE", "MCD", "PAYX", "CLX", "SN", "SGI", "TEM", "SE", "SYY", "GWRE", "CVNA", "RIVN", "NWSA", "FSS", "TKO", "OMC", "INGM", "AWK", "GOOG", "STAG", "EOG", "BMRN", "SSD", "ALL", "DUKB", "ENSG", "DCI", "ITW", "ADSK", "CENX", "AMD", "PFGC", "AIT", "ADI", "CPB", "LOGI", "LEN", "SCHW", "VTR", "AWI", "JOBY", "APD", "AVAV", "CIEN", "GATX", "AAL", "PINS", "RAL", "MCHPP", "SO", "RMD", "FITBM", "AMGN", "SYK", "U", "LFUS", "KNX", "PEP", "RBC", "KEY", "PRAX")
            val usTickersPart7 = listOf("IQV", "L", "SF", "RGTI", "MO", "BKR", "EXE", "MUSA", "WAB", "SNA", "SREA", "BWA", "BE", "UMBF", "CTVA", "HUBS", "CACI", "PEG", "VST", "NWS", "ALSN", "RDDT", "SM", "GILD", "SAIL", "ANET", "SAIA", "PODD", "DELL", "TSLA", "CORT", "DAR", "ROK", "PNFP", "APLD", "COST", "AGNCN", "HSIC", "HBANL", "TTWO", "BK", "VRSK", "IOT", "ENTG", "LEVI", "EQPT", "CCK", "CMC", "ROP", "VSAT", "O", "LUMN", "CAG", "ADC", "ESE", "SOJD", "SOLV", "ZBH", "CORZZ", "DDOG", "MAA", "CF", "ALGN", "KKR", "FDX", "IEX", "APP", "BURL", "UHAL", "PFE", "KGS", "PCVX", "ON", "PANW", "EW", "WAT", "CW", "AGCO", "ORCL", "WCC", "RPRX", "HL", "NVDA", "LDOS", "OWL", "VLO", "AYI", "TPR", "HALO", "GVA", "ROAD", "ENS", "VNO", "HAL", "DINO", "HWM", "WY", "ROST", "SSB", "VNOM")
            val usTickersPart8 = listOf("EPRT", "FCFS", "WYNN", "AAPL", "CMSC", "MCO", "IONQ", "LNC", "LW", "EXP", "WULF", "CHWY", "KNSL", "BPOP", "STEP", "JEF", "CDNS", "CTRE", "NUVL", "WMT", "LECO", "XYZ", "TXT", "BWXT", "PACS", "CINF", "INSM", "BLK", "AEIS", "ENPH", "WMS", "COLB", "RSI", "HUT", "MRSH", "INTU", "AXP", "ENJ", "NEM", "AMKR", "IP", "ADP", "NCLH", "RHP", "SOJC", "DOC", "PHM", "DECK", "MGM", "GFS", "NVR", "SRRK", "EAI", "PCG", "MSM", "RKT", "BSX", "EXPD", "EQH", "XPO", "FITBO", "WBS", "CARR", "RVMD", "FORM", "IESC", "TER", "WDC", "UI", "LPLA", "ZTS", "WAL", "WH", "RTO", "COR", "VZ", "BAH", "LINE", "NFG", "NTRS", "SCI", "AME", "SUN", "SJM", "GL", "PYPL", "FE", "MRNA", "MPC", "BLTE", "CYTK", "NDSN", "CL", "KYMR", "EXEL", "UNP", "COO", "POWL", "OMF", "LYV")
            val usTickersPart9 = listOf("PAG", "TGT", "NRG", "STRD", "HOOD", "FOXA", "BLDR", "AGNC", "RGLD", "FLR", "AXTI", "BMY", "VLY", "URBN", "CBSH", "TBB", "BTSGU", "DOCU", "MET", "AAON", "CCZ", "TJX", "UHS", "CRWV", "BBIO", "CNP", "TEX", "HQY", "GLXY", "ZBRA", "QRVO", "EQT", "ARXS", "WELL", "CFG", "BX", "MOD", "CDE", "RRC", "LIN", "EMN", "KR", "UNM", "AGNCZ", "CRL", "OTIS", "SPGI", "ROL", "CVS", "ACT", "WDAY", "MWH", "AZO", "SHW", "PRIM", "DVN", "PTCT", "GMED", "ORLY", "ZWS", "ACM", "AVGO", "SLAB", "KNTK", "CBRE", "J", "FFIV", "PSA", "DXCM", "NXST", "CPT", "CNA", "VMI", "AFL", "RMBS", "CVX", "ALLY", "WSO", "FAST", "BRKRP", "SBUX", "BAC", "KO", "TROW", "GLPI", "VRT", "LAMR", "NPO", "LGN", "AFG", "COF", "BSY", "UPS", "SNOW", "EXC", "ALAB", "TTD", "LRCX", "CMI", "ELS")
            val allUsTickers = usTickersPart0 + usTickersPart1 + usTickersPart2 + usTickersPart3 + usTickersPart4 + usTickersPart5 + usTickersPart6 + usTickersPart7 + usTickersPart8 + usTickersPart9
            val allSeedTickers = (baseTickers + krMockTickers + allUsTickers).distinct()

            // 4. Global Cleanup
            println("Performing global asset cleanup...")
            assetRepository.deleteByTickerNotIn(allSeedTickers)
            println("Asset cleanup complete.")

            // 5. Create 10000 Bots (Scaling up from 1000)
            val existingBots = userRepository.findAll().filter { it.username.startsWith("BOT_") }.map { it.username }.toSet()
            var createdCount = 0
            
            val allUsers = userRepository.findAll()
            val bots = allUsers.filter { it.username.startsWith("BOT_") }

            // Ensure all existing bots have a USD account
            bots.forEach { bot ->
                val botAccounts = accountRepository.findByUserId(bot.id)
                if (botAccounts.none { it.currency == "USD" }) {
                    val randomUsdBalance = (50_000..500_000).random().toDouble()
                    val usdAcc = accountRepository.save(Account(
                        userId = bot.id,
                        accountNumber = "9${String.format("%07d", bot.id.toInt())}-88", // 88 for USD
                        accountType = "BOT_OVERSEAS",
                        balance = randomUsdBalance,
                        currency = "USD",
                        isPrimary = false
                    ))
                    
                    // Seed some US assets
                    val botUsTickers = allUsTickers.shuffled().take((3..8).random())
                    botUsTickers.forEach { ticker ->
                        assetRepository.save(Asset(
                            accountId = usdAcc.id,
                            ticker = ticker,
                            quantity = (10..500).random(),
                            avgPrice = (50..400).random().toDouble()
                        ))
                    }
                }
            }

            for (i in 1..10000) {
                val name = "BOT_${String.format("%04d", i)}"
                if (!existingBots.contains(name)) {
                    val bot = User(
                        username = name, 
                        passwordHash = passwordEncoder.encode("bot123"), 
                        email = "$name@mts.bot", 
                        name = "Trading Bot $i"
                    )
                    val savedBot = userRepository.save(bot)
                    
                    // 1. KRW Account
                    val randomBalance = (100_000_000..1_000_000_000).random().toDouble()
                    val savedAcc = accountRepository.save(Account(
                        userId = savedBot.id,
                        accountNumber = "9${String.format("%07d", i)}-01",
                        accountType = "BOT",
                        balance = randomBalance,
                        currency = "KRW",
                        isPrimary = true
                    ))
                    
                    // 2. USD Account
                    val randomUsdBalance = (50_000..500_000).random().toDouble()
                    val usdAcc = accountRepository.save(Account(
                        userId = savedBot.id,
                        accountNumber = "9${String.format("%07d", i)}-88",
                        accountType = "BOT_OVERSEAS",
                        balance = randomUsdBalance,
                        currency = "USD",
                        isPrimary = false
                    ))
                    
                    // Initial Portfolio Seeding (KRW)
                    val botTickers = allSeedTickers.filter { it.all { c -> c.isDigit() } }.shuffled().take((5..15).random())
                    botTickers.forEach { ticker ->
                        assetRepository.save(Asset(
                            accountId = savedAcc.id,
                            ticker = ticker,
                            quantity = (100..5000).random(),
                            avgPrice = (10000..100000).random().toDouble()
                        ))
                    }

                    // Initial Portfolio Seeding (USD)
                    val botUsTickers = allUsTickers.shuffled().take((3..8).random())
                    botUsTickers.forEach { ticker ->
                        assetRepository.save(Asset(
                            accountId = usdAcc.id,
                            ticker = ticker,
                            quantity = (10..500).random(),
                            avgPrice = (50..400).random().toDouble()
                        ))
                    }
                    createdCount++
                }
            }
            if (createdCount > 0) println("$createdCount new bots created.")
            println("Data initialization finished successfully.")
        }
    }
}
