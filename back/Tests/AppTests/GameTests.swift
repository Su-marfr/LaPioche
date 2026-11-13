@testable import App
import XCTVapor

final class GameTests: XCTestCase {
    
    func testCreateGameReturnsCreated() async throws {
        try await withApp { app in
            try await app.test(.POST, "games", beforeRequest: { req in
                try req.content.encode(CreateGameDTO(
                    title: "Catan", minPlayers: 3, maxPlayers: 4, durationMinutes: 90
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .created)
                let game = try res.content.decode(GameDTO.self)
                XCTAssertEqual(game.title, "Catan")
                XCTAssertTrue(game.isAvailable)
            })
        }
    }
    
    func testCreateGameWithEmptyTitleIsRejected() async throws {
        try await withApp { app in
            try await app.test(.POST, "games", beforeRequest: { req in
                try req.content.encode(CreateGameDTO(
                    title: "", minPlayers: 3, maxPlayers: 4, durationMinutes: 90
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }
    
    func testCreateGameWithInvertedPlayerBoundsIsRejected() async throws {
        try await withApp { app in
            try await app.test(.POST, "games", beforeRequest: { req in
                try req.content.encode(CreateGameDTO(
                    title: "Catan", minPlayers: 5, maxPlayers: 2, durationMinutes: 90
                ))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }
    
    func testListGames() async throws {
        try await withApp { app in
            _ = try await createGame(app, title: "Catan")
            _ = try await createGame(app, title: "Dixit")
            
            try await app.test(.GET, "games", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(try res.content.decode([GameDTO].self).count, 2)
            })
        }
    }
    
    func testShowGame() async throws {
        try await withApp { app in
            let game = try await createGame(app)
            let id = try XCTUnwrap(game.id)
            
            try await app.test(.GET, "games/\(id)", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(try res.content.decode(GameDTO.self).id, id)
            })
        }
    }
    
    func testShowUnknownGameReturnsNotFound() async throws {
        try await withApp { app in
            try await app.test(.GET, "games/\(UUID())", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .notFound)
            })
        }
    }
    
    func testShowGameWithMalformedIDReturnsBadRequest() async throws {
        try await withApp { app in
            try await app.test(.GET, "games/not-a-uuid", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }
    
    func testPreflightRequestFromAnotherOriginIsAllowed() async throws {
        try await withApp { app in
            try await app.test(.OPTIONS, "games", beforeRequest: { req in
                req.headers.replaceOrAdd(name: .origin, value: "http://localhost:8080")
                req.headers.replaceOrAdd(name: .accessControlRequestMethod, value: "POST")
                req.headers.replaceOrAdd(name: .accessControlRequestHeaders, value: "content-type")
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .ok)
                XCTAssertEqual(res.headers.first(name: .accessControlAllowOrigin), "*")
                XCTAssertTrue(res.headers[.accessControlAllowMethods].joined(separator: ",").contains("POST"))
            })
        }
    }
    
    func testErrorResponsesCarryTheCorsHeaders() async throws {
        try await withApp { app in
            try await app.test(.GET, "games/not-a-uuid", beforeRequest: { req in
                req.headers.replaceOrAdd(name: .origin, value: "http://localhost:8080")
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
                XCTAssertEqual(res.headers.first(name: .accessControlAllowOrigin), "*")
            })
        }
    }
    
    func testUpdateGameReturnsSuccess() async throws {
        try await withApp { app in
            
            let createdGame = try await createGame(app)
            let gameID = try XCTUnwrap(createdGame.id)
            
            try await app.test(
                .PUT,
                "games/\(gameID)",
                beforeRequest: { req in
                    try req.content.encode(
                        UpdateGameDTO(
                            title: "Catan",
                            minPlayers: 2,
                            maxPlayers: 4,
                            durationMinutes: 90
                        ))
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let game = try res.content.decode(GameDTO.self)
                    XCTAssertEqual(game.title, "Catan")
                    XCTAssertEqual(game.minPlayers, 2)
                    XCTAssertEqual(game.maxPlayers, 4)
                    XCTAssertEqual(game.durationMinutes, 90)
                    XCTAssertTrue(game.isAvailable)
                })
        }
    }
    
    func testUpdateGameWithInvalidIDReturnsBadRequest() async throws {
        try await withApp { app in
            try await app.test(
                .PUT,
                "games/invalid-id",
                beforeRequest: { req in
                    try req.content.encode(
                        UpdateGameDTO(
                            title: "Catan",
                            minPlayers: 2,
                            maxPlayers: 4,
                            durationMinutes: 90
                        ))
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .badRequest)
                })
        }
    }
    
    func testUpdateGameWithInvalidDataReturnsBadRequest() async throws {
        
        try await withApp { app in
            let createdGame = try await createGame(app)
            let gameID = try XCTUnwrap(createdGame.id)
            
            try await app.test(
                .PUT,
                "games/\(gameID)",
                beforeRequest: { req in
                    try req.content.encode(
                        UpdateGameDTO(
                            title: "Catan",
                            minPlayers: 4,
                            maxPlayers: 2,
                            durationMinutes: 90
                        ))
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .badRequest)
                })
        }
    }
    
    func testUpdateUnknownGameReturnsNotFound() async throws {
        try await withApp { app in
            try await app.test(
                .PUT,
                "games/\(UUID())",
                beforeRequest: { req in
                    try req.content.encode(
                        UpdateGameDTO(
                            title: "Catan",
                            minPlayers: 2,
                            maxPlayers: 4,
                            durationMinutes: 90
                        ))
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .notFound)
                })
        }
    }
    
    func testDeleteGameReturnsNoContent() async throws {
        try await withApp { app in
            let game = try await createGame(app)
            let gameID = try XCTUnwrap(game.id)
            
            try await app.test(
                .DELETE,
                "games/\(gameID)",
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .noContent)
                }
            )
            
            try await app.test(
                .GET,
                "games/\(gameID)",
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .notFound)
                }
            )
        }
    }
    
    func testDeleteUnknownGameReturnsNotFound() async throws {
        try await withApp { app in
            try await app.test(
                .DELETE,
                "games/\(UUID())",
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .notFound)
                }
            )
        }
    }
    
    func testDeleteGameWithLoanHistoryReturnsConflict() async throws {
        try await withApp { app in
            
            let game = try await createGame(app)
            let member = try await createMember(app)
            
            let gameID = try XCTUnwrap(game.id)
            let memberID = try XCTUnwrap(member.id)
            
            try await insertLoan(
                app,
                gameID: gameID,
                memberID: memberID,
                borrowedAt: .now,
                dueAt: .distantFuture
            )
            
            try await app.test(
                .DELETE,
                "games/\(gameID)",
                afterResponse : { res async throws in
                    XCTAssertEqual(res.status, .conflict)
                }
            )
        }
    }
    
    func testDeleteGameWithCompletedLoanReturnsConflict() async throws {
        try await withApp { app in
            
            let game = try await createGame(app)
            let member = try await createMember(app)
            
            let gameID = try XCTUnwrap(game.id)
            let memberID = try XCTUnwrap(member.id)
            
            try await insertLoan(
                app,
                gameID: gameID,
                memberID: memberID,
                borrowedAt: .distantPast,
                dueAt: .distantPast,
                returnedAt: .now
            )
            
            try await app.test(
                .DELETE,
                "games/\(gameID)",
                afterResponse : { res async throws in
                    XCTAssertEqual(res.status, .conflict)
                }
            )
        }
    }
}
