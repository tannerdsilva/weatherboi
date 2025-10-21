
import ArgumentParser
import bedrock
import wireguard_userspace_nio
import RAW_dh25519
import RAW
import Logging
import bedrock_ip
import negentropy_swift
import QuickLMDB
import Foundation

@RAW_staticbuff(bytes:1000)
fileprivate struct ManyZeros:Sendable {
	init() {
		self = Self(RAW_staticbuff:ManyZeros.RAW_staticbuff_zeroed())
	}
}

@RAW_staticbuff(bytes:100)
fileprivate struct Key:Sendable { }

extension CLI {
	struct WriteLargeTransaction:ParsableCommand {
		static let configuration = CommandConfiguration(
			commandName: "write-large-transaction",
			abstract: "Do not run this if you want to keep your sanity."
		)
		
		@Option(help:"the path to the database directory, defaults to the user's home directory")
		var databasePath:Path = CLI.defaultDBBasePath()
		
		func run() throws {
			do {
				let base = Path(FileManager.default.homeDirectoryForCurrentUser.path)
				let finalPath = base.appendingPathComponent("test-db1.mdb")
				let memoryMapSize = size_t(finalPath.getFileSize() + 1 * 1024 * 1024 * 1024 * 1024) // add 5mb to the file
				let env1 = try Environment(path:finalPath.path(), flags:[.noSubDir], mapSize:memoryMapSize, maxReaders:16, maxDBs:1, mode:[.ownerReadWriteExecute, .groupReadExecute, .otherReadExecute])
				let newTrans = try Transaction(env:env1, readOnly:false)
				let testDB1 = try! Database(env:env1, name:nil, flags:[.create], tx:newTrans)
				try testDB1.deleteAllEntries(tx:newTrans)
				
				for _ in 0..<6_000_000 {
					let k = try generateSecureRandomBytes(as: Key.self)
					let val = try generateRandomBytes(count: 1000)
					try testDB1.setEntry(key: k, value: val, flags: [.noOverwrite], tx: newTrans)
				}
				
				print(try testDB1.dbStatistics(tx: newTrans).ms_entries)
				try newTrans.commit()
			} catch (let error) {
				print(error)
			}
		}
	}
}
