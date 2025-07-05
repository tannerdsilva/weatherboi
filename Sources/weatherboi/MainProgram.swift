import ArgumentParser

@main
struct CLI:AsyncParsableCommand {
	static let configuration = CommandConfiguration(
		commandName:"weatherboi",
		abstract:"a highly efficient daemon for capturing, storing, and redistributing data from on-premises weather stations.",
		version:"\(GitRepositoryInfo.tag) (\(GitRepositoryInfo.commitHash))\(GitRepositoryInfo.commitRevisionHash != nil ? " commit revision: \(GitRepositoryInfo.commitRevisionHash!.prefix(8))" : "")",
		subcommands:[
			Run.self
		]
	)
}