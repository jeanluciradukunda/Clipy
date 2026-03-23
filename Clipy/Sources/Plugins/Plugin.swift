//
//  Plugin.swift
//
//  Clipy
//
//  Plugin model for the clip processor plugin system.
//

import Foundation

struct Plugin: Identifiable, Codable {
    let id: String          // directory name
    let name: String
    let version: String
    let description: String
    let author: String
    let type: PluginType
    let trigger: PluginTrigger
    let inputTypes: [String]
    let command: String
    let timeout: Int

    var isEnabled: Bool = true
    var directoryURL: URL?

    enum PluginType: String, Codable {
        case processor
        case filter
        case annotator
    }

    enum PluginTrigger: String, Codable {
        case auto       // runs on every clipboard capture
        case manual     // user triggers explicitly
    }

    enum CodingKeys: String, CodingKey {
        case id, name, version, description, author, type, trigger
        case inputTypes = "input_types"
        case command, timeout
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // id is set externally from directory name, use placeholder
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? ""
        name = try container.decode(String.self, forKey: .name)
        version = try container.decodeIfPresent(String.self, forKey: .version) ?? "1.0"
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        author = try container.decodeIfPresent(String.self, forKey: .author) ?? ""
        type = try container.decodeIfPresent(PluginType.self, forKey: .type) ?? .processor
        trigger = try container.decodeIfPresent(PluginTrigger.self, forKey: .trigger) ?? .manual
        inputTypes = try container.decodeIfPresent([String].self, forKey: .inputTypes) ?? ["string"]
        command = try container.decode(String.self, forKey: .command)
        timeout = try container.decodeIfPresent(Int.self, forKey: .timeout) ?? 5
    }

    init(id: String, name: String, version: String, description: String, author: String,
         type: PluginType, trigger: PluginTrigger, inputTypes: [String],
         command: String, timeout: Int, directoryURL: URL?) {
        self.id = id
        self.name = name
        self.version = version
        self.description = description
        self.author = author
        self.type = type
        self.trigger = trigger
        self.inputTypes = inputTypes
        self.command = command
        self.timeout = timeout
        self.directoryURL = directoryURL
    }
}
