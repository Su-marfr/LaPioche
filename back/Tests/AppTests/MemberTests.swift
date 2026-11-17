@testable import App
import XCTVapor

final class MemberTests: XCTestCase {
    func testCreateMemberReturnsCreated() async throws {
        try await withApp { app in
            try await app.test(.POST, "members", beforeRequest: { req in
                try req.content.encode(CreateMemberDTO(name: "Camille", email: "camille@example.com"))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .created)
                XCTAssertEqual(try res.content.decode(MemberDTO.self).name, "Camille")
            })
        }
    }

    func testCreateMemberWithInvalidEmailIsRejected() async throws {
        try await withApp { app in
            try await app.test(.POST, "members", beforeRequest: { req in
                try req.content.encode(CreateMemberDTO(name: "Camille", email: "not-an-email"))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .badRequest)
            })
        }
    }

    func testCreateMemberWithDuplicateEmailReturnsConflict() async throws {
        try await withApp { app in
            _ = try await createMember(app)

            try await app.test(.POST, "members", beforeRequest: { req in
                try req.content.encode(CreateMemberDTO(name: "Autre", email: "camille@example.com"))
            }, afterResponse: { res async throws in
                XCTAssertEqual(res.status, .conflict)
            })
        }
    }

    func testShowUnknownMemberReturnsNotFound() async throws {
        try await withApp { app in
            try await app.test(.GET, "members/\(UUID())", afterResponse: { res async throws in
                XCTAssertEqual(res.status, .notFound)
            })
        }
    }
    
    func testUpdateMemberReturnsSuccess() async throws {
        try await withApp { app in
            let member = try await createMember(app)
            try await app.test(
                .PUT,
                "members/\(member.id!)",
                beforeRequest: { req in
                    try req.content.encode(
                        UpdateMemberDTO(
                            name: "Camille Pasquette",
                            email: "camille@example.com"
                        ))
                }, afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .ok)
                    let updatedMember = try res.content.decode(MemberDTO.self)
                    XCTAssertEqual(updatedMember.name, "Camille Pasquette")
                    XCTAssertEqual(updatedMember.email, "camille@example.com")
                }
            )
        }
    }
    
    func testUpdateMemberWithInvalidIDReturnsBadRequest() async throws {
        try await withApp { app in
            try await app.test(
                .PUT,
                "members/invalid-id",
                beforeRequest: { req in
                    try req.content.encode(
                        UpdateMemberDTO(
                            name: "Hironimus",
                            email: "hironimus@example.com"
                        ))
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .badRequest)
                }
            )
        }
    }
    
    func testUpdateMemberWithInvalidDataReturnsBadRequest() async throws {

        try await withApp { app in
            let member = try await createMember(app)
            let memberID = try XCTUnwrap(member.id)

            try await app.test(
                .PUT,
                "members/\(memberID)",
                beforeRequest: { req in
                    try req.content.encode(
                        UpdateMemberDTO(
                            name: "Hironimus",
                            email: "not-an-email"
                        ))
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .badRequest)
                }
            )
        }
    }

    func testUpdateUnknownMemberReturnsNotFound() async throws {
        try await withApp { app in
            try await app.test(
                .PUT,
                "members/\(UUID())",
                beforeRequest: { req in
                    try req.content.encode(
                        UpdateMemberDTO(
                            name: "Charlotte",
                            email: "charlotte@example.com"
                        ))
                },
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .notFound)
                }
            )
        }
    }

    func testUpdateMemberWithEmailAlreadyUsedByAnotherMemberReturnsConflict() async throws {
        try await withApp { app in
            let member = try await createMember(app, email: "camille@example.com")
            let anotherMember = try await createMember(app, email: "other@example.com")

            let memberID = try XCTUnwrap(member.id)

            let anotherMemberEmail = try XCTUnwrap(anotherMember.email)

            try await app.test(
                .PUT,
                "members/\(memberID)",
                beforeRequest: { req in
                    try req.content.encode(
                        UpdateMemberDTO(
                            name: member.name,
                            email: anotherMemberEmail
                        ))
                }, afterResponse : { res async throws in
                    XCTAssertEqual(res.status, .conflict)
                }
            )
        }
    }
    
    func testDeleteMemberReturnsNoContent() async throws {
        try await withApp { app in
            let member = try await createMember(app)
            let memberID = try XCTUnwrap(member.id)

            try await app.test(
                .DELETE,
                "members/\(memberID)",
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .noContent)
                }
            )

            try await app.test(
                .GET,
                "members/\(memberID)",
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .notFound)
                }
            )
        }
    }

    func testDeleteUnknownMemberReturnsNotFound() async throws {
        try await withApp { app in
            try await app.test(
                .DELETE,
                "members/\(UUID())",
                afterResponse: { res async throws in
                    XCTAssertEqual(res.status, .notFound)
                }
            )
        }
    }

    func testDeleteMemberWithLoanHistoryReturnsConflict() async throws {
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
                "members/\(memberID)",
                afterResponse : { res async throws in
                    XCTAssertEqual(res.status, .conflict)
                }
            )
        }
    }
    
    func testDeleteMemberWithCompletedLoanReturnsConflict() async throws {
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
                "members/\(memberID)",
                afterResponse : { res async throws in
                    XCTAssertEqual(res.status, .conflict)
                }
            )
        }
    }
}
