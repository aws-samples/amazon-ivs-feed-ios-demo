//
//  Stream.swift
//  ScrollingFeed
//
//  Created by Zingis, Uldis on 6/30/20.
//  Copyright © 2020 Twitch. All rights reserved.
//

import UIKit

struct Streams: Decodable {
    var streams: [Stream] = []
}

struct Stream: Decodable {
    var id: Int
    var streamInfo: StreamInfo
    var metadata: Metadata

    init(id: Int, streamInfo: StreamInfo, metadata: Metadata) {
        self.id = id
        self.streamInfo = streamInfo
        self.metadata = metadata
    }

    enum CodingKeys: String, CodingKey {
        case id
        case streamInfo = "stream"
        case metadata
    }
}

struct StreamInfo: Decodable {
    var channelArn: String
    var health: String
    var playbackUrl: String
    var startTime: String
    var state: String
    var viewerCount: Int

    init(channelArn: String, health: String, playbackUrl: String, startTime: String, state: String, viewerCount: Int) {
        self.channelArn = channelArn
        self.health = health
        self.playbackUrl = playbackUrl
        self.startTime = startTime
        self.state = state
        self.viewerCount = viewerCount
    }
}

struct Metadata: Decodable {
    var streamTitle: String
    var userAvatarUrl: String
    var userName: String

    init(streamTitle: String, userAvatarUrl: String, userName: String) {
        self.streamTitle = streamTitle
        self.userAvatarUrl = userAvatarUrl
        self.userName = userName
    }

    enum CodingKeys: String, CodingKey {
        case streamTitle
        case userAvatarUrl = "userAvatar"
        case userName
    }
}
