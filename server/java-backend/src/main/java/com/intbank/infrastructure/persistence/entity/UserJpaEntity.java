package com.intbank.infrastructure.persistence.entity;

import jakarta.persistence.*;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "users")
public class UserJpaEntity
{

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String nume;

    @Column(nullable = false)
    private String prenume;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(name = "nr_telefon", nullable = false, unique = true)
    private String nrTelefon;

    @Column(nullable = false)
    private String sex;

    @Column(name = "data_nasterii", nullable = false)
    private LocalDate dataNasterii;

    @Column(nullable = false, unique = true)
    private String cnp;

    private String judet;
    private String localitate;
    private String adresa;

    @Column(name = "cod_postal")
    private String codPostal;

    @Column(name = "place_id")
    private String placeId;

    private Double lat;
    private Double lng;

    private String bloc;
    private String scara;
    private String apartament;

    @Column(name = "cont_aprobat")
    private Boolean contAprobat = false;

    @Column(name = "termeni_acceptati")
    private Boolean termeniAcceptati = false;

    @OneToMany(mappedBy = "user", fetch = FetchType.LAZY)
    private List<AccountJpaEntity> accounts = new ArrayList<>();

    @OneToMany(mappedBy = "user", fetch = FetchType.LAZY)
    private List<CardJpaEntity> cards = new ArrayList<>();

    public Long getId()
    {
        return id;
    }

    public void setId(Long id)
    {
        this.id = id;
    }

    public String getNume()
    {
        return nume;
    }

    public void setNume(String nume)
    {
        this.nume = nume;
    }

    public String getPrenume()
    {
        return prenume;
    }

    public void setPrenume(String prenume)
    {
        this.prenume = prenume;
    }

    public String getEmail()
    {
        return email;
    }

    public void setEmail(String email)
    {
        this.email = email;
    }

    public String getNrTelefon()
    {
        return nrTelefon;
    }

    public void setNrTelefon(String nrTelefon)
    {
        this.nrTelefon = nrTelefon;
    }

    public String getSex()
    {
        return sex;
    }

    public void setSex(String sex)
    {
        this.sex = sex;
    }

    public LocalDate getDataNasterii()
    {
        return dataNasterii;
    }

    public void setDataNasterii(LocalDate dataNasterii)
    {
        this.dataNasterii = dataNasterii;
    }

    public String getCnp()
    {
        return cnp;
    }

    public void setCnp(String cnp)
    {
        this.cnp = cnp;
    }

    public String getJudet()
    {
        return judet;
    }

    public void setJudet(String judet)
    {
        this.judet = judet;
    }

    public String getLocalitate()
    {
        return localitate;
    }

    public void setLocalitate(String localitate)
    {
        this.localitate = localitate;
    }

    public String getAdresa()
    {
        return adresa;
    }

    public void setAdresa(String adresa)
    {
        this.adresa = adresa;
    }

    public String getCodPostal()
    {
        return codPostal;
    }

    public void setCodPostal(String codPostal)
    {
        this.codPostal = codPostal;
    }

    public String getPlaceId()
    {
        return placeId;
    }

    public void setPlaceId(String placeId)
    {
        this.placeId = placeId;
    }

    public Double getLat()
    {
        return lat;
    }

    public void setLat(Double lat)
    {
        this.lat = lat;
    }

    public Double getLng()
    {
        return lng;
    }

    public void setLng(Double lng)
    {
        this.lng = lng;
    }

    public String getBloc()
    {
        return bloc;
    }

    public void setBloc(String bloc)
    {
        this.bloc = bloc;
    }

    public String getScara()
    {
        return scara;
    }

    public void setScara(String scara)
    {
        this.scara = scara;
    }

    public String getApartament()
    {
        return apartament;
    }

    public void setApartament(String apartament)
    {
        this.apartament = apartament;
    }

    public Boolean getContAprobat()
    {
        return contAprobat;
    }

    public void setContAprobat(Boolean contAprobat)
    {
        this.contAprobat = contAprobat;
    }

    public Boolean getTermeniAcceptati()
    {
        return termeniAcceptati;
    }

    public void setTermeniAcceptati(Boolean termeniAcceptati)
    {
        this.termeniAcceptati = termeniAcceptati;
    }

    public List<AccountJpaEntity> getAccounts()
    {
        return accounts;
    }

    public void setAccounts(List<AccountJpaEntity> accounts)
    {
        this.accounts = accounts;
    }

    public List<CardJpaEntity> getCards()
    {
        return cards;
    }

    public void setCards(List<CardJpaEntity> cards)
    {
        this.cards = cards;
    }
}