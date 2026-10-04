from betternb_tutor.verification import DerivativeVerifier, VerificationStatus


def test_verifies_equivalent_derivative_forms() -> None:
    verifier = DerivativeVerifier()

    result = verifier.verify(
        problem="Differentiate f(x) = (x^2 + 1)^3",
        step="f'(x) = 6x(x^2 + 1)^2",
    )

    assert result.status is VerificationStatus.VERIFIED
    assert result.is_correct is True


def test_disproves_an_incorrect_chain_rule_step() -> None:
    verifier = DerivativeVerifier()

    result = verifier.verify(
        problem="Differentiate f(x) = (x^2 + 1)^3",
        step="f'(x) = 3*(x^2 + 1)^2",
    )

    assert result.status is VerificationStatus.VERIFIED
    assert result.is_correct is False


def test_unsupported_or_unsafe_input_is_inconclusive() -> None:
    verifier = DerivativeVerifier()

    unsupported = verifier.verify(
        problem="Prove every compact subset of R is closed",
        step="Let K be compact",
    )
    unsafe = verifier.verify(
        problem="Differentiate f(x) = __import__('os').system('echo nope')",
        step="f'(x) = 0",
    )

    assert unsupported.status is VerificationStatus.INCONCLUSIVE
    assert unsafe.status is VerificationStatus.INCONCLUSIVE
