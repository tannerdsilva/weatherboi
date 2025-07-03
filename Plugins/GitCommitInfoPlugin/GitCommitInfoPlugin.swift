import PackagePlugin
import Foundation

@main
struct GitCommitInfoPlugin:BuildToolPlugin {
	func createBuildCommands(context:PluginContext, target: Target) throws -> [Command] {
		let outputDir = context.pluginWorkDirectoryURL
		let packageDir = context.package.directoryURL
		let commitFile = outputDir.appendingPathComponent("GitRepositoryInfo.swift")
		try? FileManager.default.removeItem(at: commitFile) // Remove any existing file to ensure we generate a fresh one
		let script = """
		cd "\(packageDir.path)" && \
		commit=$(git rev-parse HEAD) && \
		tag=$(git describe --tags --abbrev=0 2>/dev/null || echo "") && \
		diff=$(git diff HEAD) && \
		if [ -z "$diff" ]; then \
			revisionLiteral=nil; \
		else \
			revision=$(printf '%s' "$diff" | shasum -a 1 | cut -d' ' -f1); \
			revisionLiteral="\\\"${revision}\\\""; \
		fi && \
		echo "// Auto-generated
		public struct GitRepositoryInfo {
			public static let commitHash = \\"${commit}\\"
			public static let tag = \\"${tag}\\"
			public static let commitRevisionHash:String? = ${revisionLiteral}
		}" > "\(commitFile.path)"
		"""        
		let timestamp = ISO8601DateFormatter().string(from: Date())
		return [
			.prebuildCommand(
				displayName: "Generate GitRepositoryInfo.swift",
				executable: .init(filePath: "/bin/sh"),
				arguments: ["-c", script],
				environment: ["TIMESTAMP": timestamp],
				outputFilesDirectory:outputDir
			)
		]
	}
}
