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
import UIKit

class StreamingViewController: UITableViewController, StreamingModelDelegate, UISearchBarDelegate {

    let model:StreamingModel;
    let reuseIdentifier = "com.sackfield.streamingviewcontroller";

    init(model: StreamingModel) {
        self.model = model
        super.init(nibName: nil, bundle: nil)
        self.model.delegate = self
        self.tableView.register(StreamingTableViewCell.self, forCellReuseIdentifier: reuseIdentifier)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // UIViewController

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.view.backgroundColor = UIColor.purple
        self.model.load()
        self.title = "Twitter Hose"
    }

    // StreamingModelDelegate

    func streamingModelDidFailToFetchTwitterStream(model: StreamingModel, error: NSError) {
        let title = error.userInfo[NSLocalizedFailureReasonErrorKey] as! String
        let message = error.userInfo[NSLocalizedRecoverySuggestionErrorKey] as! String
        let alertController = UIAlertController.init(title: title, message: message, preferredStyle: .alert)
        let OKAction = UIAlertAction(title: "OK", style: .default) { action in
            self.model.load()
        }
        alertController.addAction(OKAction)
    }

    func streamingModelDidLoad(model: StreamingModel) {
    }

    func streamingModelDidFetchTweet(model: StreamingModel, tweet: Dictionary<String, Any>) {
        self.tableView.insertRows(at: [IndexPath.init(row: 0, section: 0)], with: UITableViewRowAnimation.left)
    }

    // UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.model.numberOfTweets();
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath)

        let tweet = self.model.tweetAtIndex(index: indexPath.row)
        let text = tweet["text"] as? String
        let user = tweet["user"] as! Dictionary<String, Any?>
        let screenName = user["screen_name"] as? String

        cell.textLabel!.text = text
        cell.detailTextLabel!.text = screenName

        return cell
    }

    // UITableViewDelegate

    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 70.0
    }

    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let searchBar = UISearchBar.init(frame: CGRect.zero)
        searchBar.autoresizingMask = UIViewAutoresizing.flexibleWidth
        searchBar.delegate = self
        return searchBar
    }

    // UISearchBarDelegate

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        self.model.fetchStreamForText(text: searchBar.text)
        self.tableView.reloadData()
        searchBar.resignFirstResponder()
        self.title = "Twitter Hose (\(searchBar.text!))"
    }
}

