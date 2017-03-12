/*
 * Copyright (c) 2017 Will Sackfield.
 *
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 */
import Foundation

import Accounts
import Social

protocol StreamingModelDelegate: class {
    func streamingModelDidFailToFetchTwitterStream(model: StreamingModel, error: NSError)
    func streamingModelDidLoad(model: StreamingModel)
    func streamingModelDidFetchTweet(model: StreamingModel, tweet: Dictionary<String, Any>)
}

enum StreamingModelErrorCode : Int {
    case loginNotSuccessful
}

class StreamingModel: NSObject, URLSessionDelegate, URLSessionDataDelegate {

    weak var delegate:StreamingModelDelegate?;

    private var twitterAccount:ACAccount?;
    private var task:URLSessionDataTask?;
    private var tweets:NSMutableOrderedSet;
    private var tweetData:NSMutableString;

    let errorDomain = "com.sackfield.streamingmodel"
    private var session:URLSession?;

    init(sessionConfig: URLSessionConfiguration) {
        self.tweets = NSMutableOrderedSet.init()
        self.tweetData = NSMutableString.init()
        super.init()
        self.session = URLSession.init(configuration: sessionConfig, delegate: self, delegateQueue: nil)
    }

    func load() {
        let store = ACAccountStore();
        let accountType = store.accountType(withAccountTypeIdentifier: ACAccountTypeIdentifierTwitter)
        store.requestAccessToAccounts(with: accountType, options: nil) {
            (success: Bool, error: Error?) -> Void in
            if error != nil {
                self.delegate?.streamingModelDidFailToFetchTwitterStream(model: self, error: error as! NSError)
                return
            }

            if !success {
                let error = NSError.init(domain: self.errorDomain, code: StreamingModelErrorCode.loginNotSuccessful.rawValue, userInfo: nil)
                self.delegate?.streamingModelDidFailToFetchTwitterStream(model: self, error: error)
            }

            self.twitterAccount = store.accounts(with: accountType).last as! ACAccount?
            self.delegate?.streamingModelDidLoad(model: self)
        }
    }

    func fetchStreamForText(text: String?) {
        if self.task != nil {
            self.task?.cancel()
        }

        if text == nil {
            return
        }

        self.tweetData.setString("")
        self.tweets.removeAllObjects()

        let url = URL.init(string: "https://stream.twitter.com/1.1/statuses/filter.json")
        let parameters = [ "track" : text ]
        let request = SLRequest.init(forServiceType: SLServiceTypeTwitter, requestMethod: SLRequestMethod.GET, url: url, parameters: parameters)
        request?.account = self.twitterAccount
        let urlRequest = request?.preparedURLRequest()

        self.task = self.session?.dataTask(with: urlRequest!)
        self.task?.resume()
    }

    func numberOfTweets() -> Int {
        return self.tweets.count
    }

    func tweetAtIndex(index: Int) -> Dictionary<String, Any> {
        return self.tweets.object(at: self.tweets.count - 1 - index) as! Dictionary<String, Any>
    }

    // URLSessionDataDelegate

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let jsonString = String.init(data: data, encoding: String.Encoding.utf8)
        DispatchQueue.main.async {  // TODO: Future improvement, put the JSON parsing logic on another queue?
            self.tweetData.append(jsonString!)
            var stringRange = NSRange.init(location: 0, length: 0)
            while stringRange.location < self.tweetData.length {
                let searchRange = NSRange.init(location: stringRange.location, length: self.tweetData.length - stringRange.location)
                stringRange = self.tweetData.range(of: "}", options: String.CompareOptions.caseInsensitive, range: searchRange)
                if stringRange.location == NSNotFound {
                    break
                }
                let dictString = self.tweetData.substring(to: stringRange.location + 1)
                let dictData = dictString.data(using: String.Encoding.utf8)
                do {
                    let json = try JSONSerialization.jsonObject(with: dictData!) as? [String: Any]
                    if !self.tweets.contains(json!) { // Filter out duplicates
                        self.tweets.add(json!) // TODO: Potential problem? We could run out of memory after a couple of days
                        self.delegate?.streamingModelDidFetchTweet(model: self, tweet: json!)
                    }
                    self.tweetData.replaceCharacters(in: NSRange.init(location: 0, length: stringRange.location + 1), with: "")
                    stringRange.location = 0
                } catch {
                    // This is an expected error as we parse through the data
                }
                stringRange.location += 1
            }
        }
    }
}
