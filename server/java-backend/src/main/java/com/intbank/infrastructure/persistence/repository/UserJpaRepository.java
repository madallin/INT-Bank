package com.intbank.infrastructure.persistence.repository;

import com.intbank.infrastructure.persistence.entity.UserJpaEntity;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

@Repository
public interface UserJpaRepository extends JpaRepository<UserJpaEntity, Long>
{

    Optional<UserJpaEntity> findByEmail(String email);

    Optional<UserJpaEntity> findByNrTelefon(String nrTelefon);

    Optional<UserJpaEntity> findByCnp(String cnp);
}