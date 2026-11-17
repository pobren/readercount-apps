// Sample stats for screenshots and App Store review: start the app with -demo (and -tab live, -tab health, -tab more
// or -tab account) and it shows these instead of signing in. Nothing is sent anywhere in demo mode.

import Foundation

enum Demo {
    static var on: Bool { ProcessInfo.processInfo.arguments.contains("-demo") }

    static var tab: String? {
        let a = ProcessInfo.processInfo.arguments
        guard let i = a.firstIndex(of: "-tab"), i + 1 < a.count else { return nil }
        return a[i + 1]
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ json: String) -> T? {
        try? JSONDecoder().decode(T.self, from: Data(json.utf8))
    }

    static var me: Me? { decode(Me.self, meJSON) }
    static var overview: Overview? { decode(Overview.self, overviewJSON) }
    static var live: Live? { decode(Live.self, liveJSON) }
    static var health: Health? { decode(Health.self, healthJSON) }

    static let meJSON = #"""
{
 "email": "you@example.com",
 "plan": {
  "name": "Pro",
  "pro": true,
  "agency": false,
  "sites": 10,
  "views": 100000
 },
 "sites": [
  "myblog.com",
  "recipes.example"
 ],
 "devices": 1
}
"""#

    static let overviewJSON = #"""
{
 "site": "myblog.com",
 "period": "7d",
 "from": "2026-11-07",
 "to": "2026-11-13",
 "totals": {
  "visitors": 2819,
  "views": 4084,
  "avg_seconds": 148,
  "bounce_percent": 41,
  "on_site_now": 7
 },
 "previous_period": {
  "visitors": 2604,
  "views": 3810
 },
 "per_day": [
  {
   "day": "2026-11-07",
   "views": 572,
   "visitors": 395
  },
  {
   "day": "2026-11-08",
   "views": 638,
   "visitors": 440
  },
  {
   "day": "2026-11-09",
   "views": 645,
   "visitors": 445
  },
  {
   "day": "2026-11-10",
   "views": 651,
   "visitors": 449
  },
  {
   "day": "2026-11-11",
   "views": 598,
   "visitors": 413
  },
  {
   "day": "2026-11-12",
   "views": 508,
   "visitors": 351
  },
  {
   "day": "2026-11-13",
   "views": 472,
   "visitors": 326
  }
 ],
 "top_pages": [
  {
   "page": "/best-email-hosting-uk/",
   "visitors": 812,
   "views": 1190,
   "avg_seconds": 184
  },
  {
   "page": "/proton-mail-review/",
   "visitors": 544,
   "views": 702,
   "avg_seconds": 241
  },
  {
   "page": "/how-to-set-up-dmarc/",
   "visitors": 391,
   "views": 512,
   "avg_seconds": 312
  },
  {
   "page": "/fastmail-vs-gmail/",
   "visitors": 288,
   "views": 350,
   "avg_seconds": 167
  },
  {
   "page": "/",
   "visitors": 260,
   "views": 401,
   "avg_seconds": 52
  },
  {
   "page": "/newsletter/",
   "visitors": 141,
   "views": 160,
   "avg_seconds": 95
  },
  {
   "page": "/about/",
   "visitors": 88,
   "views": 97,
   "avg_seconds": 61
  }
 ],
 "sources": [
  {
   "source": "Google",
   "visitors": 1630
  },
  {
   "source": "Direct",
   "visitors": 512
  },
  {
   "source": "Reddit",
   "visitors": 286
  },
  {
   "source": "Bing",
   "visitors": 141
  },
  {
   "source": "Bluesky",
   "visitors": 96
  },
  {
   "source": "DuckDuckGo",
   "visitors": 77
  },
  {
   "source": "Newsletter",
   "visitors": 64
  }
 ],
 "campaigns": [
  {
   "campaign": "november-news",
   "visitors": 64
  }
 ],
 "countries": [
  {
   "country": "GB",
   "visitors": 1402
  },
  {
   "country": "US",
   "visitors": 611
  },
  {
   "country": "IE",
   "visitors": 204
  },
  {
   "country": "DE",
   "visitors": 141
  },
  {
   "country": "CA",
   "visitors": 120
  },
  {
   "country": "AU",
   "visitors": 98
  }
 ],
 "devices": [
  {
   "device": "mobile",
   "visitors": 1490
  },
  {
   "device": "desktop",
   "visitors": 1201
  },
  {
   "device": "tablet",
   "visitors": 91
  }
 ],
 "browsers": [
  {
   "browser": "Chrome",
   "visitors": 1210
  },
  {
   "browser": "Safari",
   "visitors": 1088
  },
  {
   "browser": "Firefox",
   "visitors": 201
  }
 ],
 "clicks": [
  {
   "link": "https://proton.me/mail",
   "type": "link",
   "page": "/proton-mail-review/",
   "clicks": 96
  }
 ]
}
"""#

    static let liveJSON = #"""
{
 "site": "myblog.com",
 "now": 1794580000000,
 "total": 7,
 "pages": [
  {
   "path": "/best-email-hosting-uk/",
   "n": 3
  },
  {
   "path": "/proton-mail-review/",
   "n": 2
  },
  {
   "path": "/how-to-set-up-dmarc/",
   "n": 1
  },
  {
   "path": "/",
   "n": 1
  }
 ],
 "sources": [
  {
   "name": "Google",
   "n": 4
  },
  {
   "name": "Reddit",
   "n": 2
  },
  {
   "name": "Direct",
   "n": 1
  }
 ],
 "visitors": [
  {
   "country": "GB",
   "town": "Leeds",
   "region": "England",
   "device": "mobile",
   "browser": "Safari",
   "os": "iOS",
   "source": "Google",
   "first": 1794579400000,
   "last": 1794579970000,
   "views": 1,
   "page": "/best-email-hosting-uk/",
   "away": 0,
   "steps": [
    {
     "ts": 1794579940000,
     "kind": "view",
     "path": "/best-email-hosting-uk/",
     "target": null,
     "seconds": 95
    }
   ]
  },
  {
   "country": "US",
   "town": "Austin",
   "region": "Texas",
   "device": "desktop",
   "browser": "Chrome",
   "os": "macOS",
   "source": "Reddit",
   "first": 1794579400000,
   "last": 1794579970000,
   "views": 3,
   "page": "/proton-mail-review/",
   "away": 0,
   "steps": [
    {
     "ts": 1794579820000,
     "kind": "view",
     "path": "/fastmail-vs-gmail/",
     "target": null,
     "seconds": 140
    },
    {
     "ts": 1794579880000,
     "kind": "view",
     "path": "/proton-mail-review/",
     "target": null,
     "seconds": 60
    },
    {
     "ts": 1794579940000,
     "kind": "click",
     "path": "/proton-mail-review/",
     "target": "https://proton.me/mail",
     "seconds": 0
    }
   ]
  },
  {
   "country": "IE",
   "town": "Dublin",
   "region": "Leinster",
   "device": "desktop",
   "browser": "Firefox",
   "os": "Windows",
   "source": "Google",
   "first": 1794579400000,
   "last": 1794579970000,
   "views": 1,
   "page": "/how-to-set-up-dmarc/",
   "away": 0,
   "steps": [
    {
     "ts": 1794579940000,
     "kind": "view",
     "path": "/how-to-set-up-dmarc/",
     "target": null,
     "seconds": 210
    }
   ]
  },
  {
   "country": "GB",
   "town": "Bristol",
   "region": "England",
   "device": "mobile",
   "browser": "Chrome",
   "os": "Android",
   "source": "Direct",
   "first": 1794579400000,
   "last": 1794579970000,
   "views": 1,
   "page": "/",
   "away": 1794579960000,
   "steps": [
    {
     "ts": 1794579940000,
     "kind": "view",
     "path": "/",
     "target": null,
     "seconds": 20
    }
   ]
  }
 ]
}
"""#

    static let healthJSON = #"""
{
 "site": "myblog.com",
 "health": [
  {
   "level": "fix",
   "title": "3 links go to pages that are missing",
   "detail": "Readers clicked links on /fastmail-vs-gmail/ that lead to pages that no longer exist.",
   "links": [
    "https://myblog.com/fastmail-vs-gmail/"
   ],
   "key": "broken"
  },
  {
   "level": "attention",
   "title": "/how-to-set-up-dmarc/ is slow on phones",
   "detail": "It took 4.2 seconds to show on phones this week. Large images are the usual cause.",
   "links": [],
   "key": "slow"
  }
 ],
 "marked": [],
 "what_to_fix": [
  {
   "kind": "page-two",
   "page": "/fastmail-vs-gmail/",
   "query": "fastmail vs gmail",
   "what": "Nearly on page one of Google for \"fastmail vs gmail\" (place 11).",
   "todo": "Add a short comparison table near the top and link to it from your Fastmail review."
  },
  {
   "kind": "few-clicks",
   "page": "/best-email-hosting-uk/",
   "query": "best email hosting uk",
   "what": "Seen 4,120 times in Google but clicked only 61 times.",
   "todo": "Try a clearer title that says who it's for and the year."
  }
 ]
}
"""#
}
